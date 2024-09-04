const Parser = @This();

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

const Arg = @import("../Arg.zig");
const Command = @import("../Command.zig");
const Tokenizer = @import("../Tokenizer.zig");
const Token = Tokenizer.Token;

const ParseResult = @import("ParseResult.zig");
const MatchedArgValue = ParseResult.MatchedArgValue;
const parse_error = @import("parse_error.zig");
const ParseError = parse_error.ParseError;
const ParseErrorContext = parse_error.ParseErrorContext;
const AbstractOptionToken = @import("AbstractOptionToken.zig");
const ShortOptionIterator = @import("ShortOptionIterator.zig");

/// A complete error type returned by the parser.
pub const Error = ParseError || Allocator.Error;

allocator: Allocator,
/// A tokenizer to tokenize the `argv`.
tokenizer: Tokenizer,
/// A command to parse.
command: *const Command,
/// Core structure to store parse result.
result: ParseResult,
/// Custom error payload or context tracer.
error_context: ParseErrorContext,

/// Initilizes the parser with a given source of arguments for a given command.
pub fn init(allocator: Allocator, argv: []const [:0]const u8, command: *const Command) Parser {
    return Parser{
        .allocator = allocator,
        .tokenizer = Tokenizer.init(argv),
        .command = command,
        .result = ParseResult.init(allocator, command),
        .error_context = .none,
    };
}

/// Parses the provided `argv`.
pub fn parse(self: *Parser) Error!ParseResult {
    errdefer self.result.deinit();

    const takes_pos_args = self.command.countPositionalArgs() >= 1;
    // We use this flag to check whether we parse all the positional arguments
    // or not after parsing is complete.
    var parsed_all_pos_args = false;

    // Highest positional argument index accquired by any arg.
    const highest_pos_arg_index = self.highestPositionalArgIndex();
    // Positional argument index (relative to highest index) where the parser
    // is currently.
    var current_pos_arg_index: usize = 1;

    while (self.tokenizer.nextToken()) |*token| {
        // Stop the parsing as soon as we encounter help flag.
        if (mem.eql(u8, token.value, "help") or mem.eql(u8, token.value, "h")) {
            self.result.setContainsHelpFlag(true);
            return self.result;
        }

        if (token.isShortOption()) {
            try self.parseShortOption(AbstractOptionToken.from(token));
            continue;
        }

        if (token.isLongOption()) {
            try self.parseLongOption(AbstractOptionToken.from(token));
            continue;
        }

        // Current token is likely to be a positonal argument.
        if (takes_pos_args and !parsed_all_pos_args) {
            try self.parsePositionalArg(token, current_pos_arg_index);
            current_pos_arg_index += 1;
            parsed_all_pos_args = (current_pos_arg_index > highest_pos_arg_index);
            continue;
        }

        // Current token is likely to be a subcommand.
        try self.result.setSubcommandParseResult(try self.parseSubcommand(token.value));
    }

    // Validate requirements of command.
    //
    // 1. Validate the requirement of positional arguments.
    const is_pos_arg_required = self.command.hasProperty(.positional_arg_required);

    if (takes_pos_args and is_pos_arg_required and !parsed_all_pos_args) {
        self.error_context = ParseErrorContext{
            .command_argument_not_provided = self.command.name,
        };
        return Error.CommandArgumentNotProvided;
    }

    // 2. Validate the requirement of subcommand.
    const is_subcommand_required = self.command.hasProperty(.subcommand_required);
    const parsed_any_subcommand = self.result.getSubcommandParseResult() != null;

    if (is_subcommand_required and !parsed_any_subcommand) {
        self.error_context = ParseErrorContext{
            .command_subcommand_not_provided = self.command.name,
        };
        return Error.CommandSubcommandNotProvided;
    }

    // 3. Options are not required to validate here as they are validate during
    //    the parsing by their respective parser functions (`parseShortOption`,
    //    `parseLongOption`).
    return self.result;
}

/// Returns the highest positional argument index acquired by any argument of a
/// current command.
fn highestPositionalArgIndex(self: *const Parser) usize {
    var highest_index: usize = 1;

    for (self.command.positional_args.items) |pos_arg| {
        std.debug.assert(pos_arg.index != null);
        // Unwrapping the index is completely safe, as it is guranteed to
        // set for all positional arguments.
        const current_arg_index = pos_arg.index.?;

        if (current_arg_index > highest_index) {
            highest_index = current_arg_index;
        }
    }

    return highest_index;
}

/// Parses the given token as a value of positional argument.
///
/// # Errors
///
/// Returns an error if parsing fails due to any unsatisfactory condition.
fn parsePositionalArg(self: *Parser, token: *const Token, current_position: usize) Error!void {
    // Defination of a positional argument.
    const arg = self.command.findPositionalArgByIndex(current_position) orelse return;
    // Value provided on the command line.
    const given_value = token.value;

    // Before consuming any other values from `argv`, first try if the current
    // value is splitable.
    const new_value = try self.splitValueIfPossible(arg, given_value);
    // If value is splitted, that means the separator was present.
    if (new_value.isMany()) {
        return self.insertMatchedArg(arg, new_value);
    }

    // Proceed to consume more.
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    // Try to find upper limitation on how many values we can consume.
    var num_values_to_consume = arg.max_values orelse arg.min_values;

    // If upper limitation is not found, try different way to find it.
    if (num_values_to_consume == null) {
        // If an arg can contain as much as values we can consume, proceed it.
        if (arg.hasProperty(.takes_multiple_values)) {
            // First append the value which we received at the argument.
            try self.validateAndAppendValue(arg, given_value, &values);
            // And then consume rest from the tokenizer.
            try self.consumeValuesTillNextOption(arg, &values);
            // Set the argument value and return.
            return self.insertMatchedArg(arg, MatchedArgValue.many(values));
        }

        // Fallback to single value and let the rest code handle it.
        //
        // Although we already received a single value at the argument we can't
        // just set it and return because it is necessary to handle a situation
        // when max or min is set to `1` intentionally by the user.
        num_values_to_consume = 1;
    }

    // If upper limitation is found, proceed accordingly.
    if (num_values_to_consume) |num_values| {
        // Either we have set it as fallback or user set it intentionally.
        if (num_values == 1) {
            try self.validateValue(arg, given_value);
            try self.insertMatchedArg(arg, MatchedArgValue.single(given_value));
            // Redundant. Destory it and return.
            values.deinit();
            return;
        }

        // Proceed to consume more from `argv`.
        //
        // First append the value, received at the argument.
        try self.validateAndAppendValue(arg, given_value, &values);
        // We have already append one of the value.
        const new_num_values = num_values -% 1;
        // Consume rest of the values.
        try self.consumeNValues(arg, new_num_values, &values);
    }

    return self.insertMatchedArg(arg, MatchedArgValue.many(values));
}

/// Parses the given token as a short argument.
///
/// # Errors
///
/// Returns an error if validation fails or requirements doesn't meet.
fn parseShortOption(self: *Parser, token: AbstractOptionToken) Error!void {
    var option_iter = ShortOptionIterator.init(
        token.optionName(),
        token.optionAttachedValue(),
    );

    while (option_iter.next()) |option| {
        const arg = self.command.findShortOption(option) orelse {
            self.error_context = ParseErrorContext{
                .unrecognized_argument = option_iter.getCurrentOptionAsStr(),
            };
            return Error.UnrecognizedArgument;
        };

        if (!arg.hasProperty(.takes_value)) {
            if (!option_iter.optionContainsValue()) {
                try self.insertMatchedArg(arg, MatchedArgValue.none());
                continue;
            }

            self.error_context = ParseErrorContext{ .unexpected_argument_value = .{
                .argument = arg.name,
                .value = option_iter.getOptionValue().?,
            } };
            return Error.UnexpectedArgumentValue;
        }

        const attached_value = option_iter.getOptionValue() orelse blk: {
            if (option_iter.hasOptionsLeft()) {
                // Take remaining options as value of current option.
                //
                // For e.x.: if '-xyz' is passed and '-x' takes value take 'yz'
                //           as value even if they are passed as options.
                break :blk option_iter.getRemainingOptions();
            } else {
                break :blk null;
            }
        };
        try self.insertMatchedArg(arg, try self.parseOptionValue(arg, attached_value));
    }
}

/// Parses the given token as a long argument.
///
/// # Errors
///
/// Returns an error if validation fails or requirements doesn't meet.
fn parseLongOption(self: *Parser, token: AbstractOptionToken) Error!void {
    const arg = self.command.findLongOption(token.optionName()) orelse {
        self.error_context = ParseErrorContext{ .unrecognized_argument = token.optionName() };
        return Error.UnrecognizedArgument;
    };

    if (arg.hasProperty(.takes_value)) {
        // Takes value; proceed accordingly.
        const value = try self.parseOptionValue(arg, token.optionAttachedValue());
        return self.insertMatchedArg(arg, value);
    } else if (token.optionAttachedValue()) |attached_value| {
        // Doesn't take value; but provided.
        self.error_context = ParseErrorContext{
            .unexpected_argument_value = .{
                .argument = token.optionName(),
                .value = attached_value,
            },
        };
        return Error.UnexpectedArgumentValue;
    } else {
        // Doesn't take value; not provided.
        return self.insertMatchedArg(arg, MatchedArgValue.none());
    }
}

/// Parses the attached value of an option or consumes from the `argv`.
///
/// # Errors
///
/// Returns an error if validation fails.
fn parseOptionValue(
    self: *Parser,
    arg: *const Arg,
    attached_value: ?[]const u8,
) Error!MatchedArgValue {
    // If the value is directly provided by attaching it with `=` then beyond
    // that don't consume any other values.
    if (attached_value) |value| {
        const new_value = try self.splitValueIfPossible(arg, value);

        // If the value remains unmodified, then validate it before returning.
        if (new_value.isSingle()) {
            try self.validateValue(arg, new_value.single);
        }

        return new_value;
    }

    // Value is not attached; prepare to consume.
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    // Try to find upper limitation on how many values we can consume.
    var num_values_to_consume = arg.max_values orelse arg.min_values;

    // If upper limitation is not found, try different approach to get it.
    if (num_values_to_consume == null) {
        // If an arg can contain as much as values we can consume, proceed it.
        if (arg.hasProperty(.takes_multiple_values)) {
            try self.consumeValuesTillNextOption(arg, &values);
            return MatchedArgValue.many(values);
        }
        // Arg is expecting finite number of values but neither the min/max nor
        // the `.takes_multiple_values` property is set therefore use the sensible
        // default limitation to consume values in correct amount.
        num_values_to_consume = 1;
    }

    // If upper limitation is found then consume the values accordingly.
    if (num_values_to_consume) |num_values| {
        try self.consumeNValues(arg, num_values, &values);

        if (num_values != 0 and values.items.len == 0) {
            self.error_context = ParseErrorContext{ .argument_value_not_provided = arg.name };
            return Error.ArgumentValueNotProvided;
        }
    }

    // If we have consumed a single value only, check if the policy of an arg
    // allows to return it as a single value.
    if (values.items.len == 1 and !arg.hasProperty(.takes_multiple_values)) {
        const value = values.pop();
        values.deinit();
        // No verification required here as it is already verfied while consuming.
        return MatchedArgValue.single(value);
    }

    // Doesn't allows, return as-is.
    return MatchedArgValue.many(values);
}

/// Converts the given value to `MatchedArgValue.many` type, if the given arg
/// has set `values_delimeter`; otherwise returns it as a `MatchedArgValue.single`.
fn splitValueIfPossible(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
) Error!MatchedArgValue {
    const values_separator = arg.values_delimiter orelse {
        return MatchedArgValue.single(value);
    };

    // If the given value doesn't contains separator return it immediately so
    // that we don't perform any unnecessary operation.
    if (!mem.containsAtLeast(u8, value, 1, values_separator)) {
        return MatchedArgValue.single(value);
    }

    // Proceed to split.
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    var values_iter = mem.splitSequence(u8, value, values_separator);
    while (values_iter.next()) |subvalue| {
        try self.validateAndAppendValue(arg, subvalue, &values);
    }

    return MatchedArgValue.many(values);
}

/// Consumes `n` values from the `argv` into the given `list`.
///
/// # Errors
///
/// Returns an error if validation fails.
fn consumeNValues(
    self: *Parser,
    arg: *const Arg,
    n: usize,
    list: *std.ArrayList([]const u8),
) Error!void {
    for (0..n) |_| {
        const value = self.tokenizer.nextNonOptionArg() orelse return;
        try self.validateAndAppendValue(arg, value, list);
    }
}

/// Until the option is not encountered, it continuously consumes value into
/// the given `list`.
///
/// # Errors
///
/// Returns an error if validation fails.
fn consumeValuesTillNextOption(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
) Error!void {
    while (self.tokenizer.nextNonOptionArg()) |value| {
        try self.validateAndAppendValue(arg, value, list);
    }
}

/// Validates and appends the given `value` into the given `list`.
///
/// # Errors
///
/// Returns an error if validation fails.
fn validateAndAppendValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    list: *std.ArrayList([]const u8),
) Error!void {
    try self.validateValue(arg, value);
    try list.append(value);
}

/// Inserts the given argument as a matched argument with the given value.
///
/// # Errors
///
/// Returns an error if value cannot be insert due to invalidation.
fn insertMatchedArg(self: *Parser, arg: *const Arg, value: MatchedArgValue) Error!void {
    errdefer if (value.isMany()) value.many.deinit();

    try self.validateValuesCount(arg, value.count());
    try self.result.insertMatchedArg(arg.name, value);
}

/// Validates the given value according the requirements of given argument.
///
/// # Errors
///
/// Returns an error if validation fails.
fn validateValue(self: *Parser, arg: *const Arg, value: []const u8) Error!void {
    if (value.len == 0 and !arg.hasProperty(.allow_empty_value)) {
        self.error_context = ParseErrorContext{ .empty_argument_value = arg.name };
        return Error.EmptyArgumentValue;
    }

    if (!arg.isValidValue(value)) {
        self.error_context = ParseErrorContext{ .invalid_argument_value = .{
            .argument = arg.name,
            .invalid_value = value,
            .valid_values = arg.valid_values.?,
        } };
        return Error.InvalidArgumentValue;
    }
}

/// Checks whether given count of values meets the requirement of an given arg.
///
/// # Errors
///
/// Returns an error if validation fails.
fn validateValuesCount(self: *Parser, arg: *const Arg, count: usize) Error!void {
    if ((arg.min_values != null) and (count < arg.min_values.?)) {
        self.error_context = ParseErrorContext{ .too_few_argument_value = .{
            .argument = arg.name,
            .num_values = count,
            .min_values = arg.min_values.?,
        } };
        return Error.TooFewArgumentValue;
    }

    if ((arg.max_values != null) and (count > arg.max_values.?)) {
        self.error_context = ParseErrorContext{ .too_many_argument_value = .{
            .argument = arg.name,
            .num_values = count,
            .max_values = arg.max_values.?,
        } };
        return Error.TooManyArgumentValue;
    }
}

/// Parses the specified named subcommand.
fn parseSubcommand(self: *Parser, subcommand_name: []const u8) Error!ParseResult {
    const subcmd = self.command.findSubcommand(subcommand_name) orelse {
        self.error_context = ParseErrorContext{ .unrecognized_command = subcommand_name };
        return Error.UnrecognizedCommand;
    };

    // Create the full name of the current subcommand.
    var abs_name = ParseResult.ParsedCommand.AbsoluteName.init(self.allocator);
    // First append the parent command name.
    try abs_name.appendSlice(self.result.getCommand().name());
    // Followed by a whitespace.
    try abs_name.append(' ');
    // Then append the current subcommand name.
    try abs_name.appendSlice(subcmd.name);

    const argv = self.tokenizer.remainingArgs() orelse {
        // Argv is empty.
        //
        // Return an error if positional argument is required.
        if (subcmd.hasProperty(.positional_arg_required)) {
            self.error_context = ParseErrorContext{
                .command_argument_not_provided = subcommand_name,
            };
            return Error.CommandArgumentNotProvided;
        }

        // Otherwise return an empty result.
        var parse_result = ParseResult.init(self.allocator, subcmd);
        // But before, set the subcommand full name.
        parse_result.command.absolute_name = abs_name;
        return parse_result;
    };

    var parser = Parser.init(self.allocator, argv, subcmd);
    // Set the subcommand full name in its parser.
    parser.result.command.absolute_name = abs_name;

    if (parser.parse()) |parse_result| {
        return parse_result;
    } else |err| {
        // Bubble up the error context.
        self.error_context = parser.error_context;
        return err;
    }
}
