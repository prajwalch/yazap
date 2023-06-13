const Parser = @This();

const std = @import("std");
const args_context = @import("args_context.zig");
const erro = @import("error.zig");
const Arg = @import("Arg.zig");
const Command = @import("Command.zig");
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArgsContext = args_context.ArgsContext;
const MatchedSubCommand = args_context.MatchedSubCommand;

const Error = erro.ParseError || erro.AllocatorError;

const ShortOption = struct {
    name: []const u8,
    value: ?[]const u8,
    cursor: usize,

    pub fn init(name: []const u8, value: ?[]const u8) ShortOption {
        return ShortOption{
            .name = name,
            .value = value,
            .cursor = 0,
        };
    }

    pub fn next(self: *ShortOption) ?u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor += 1;

        return self.name[self.cursor];
    }

    pub fn getValue(self: *ShortOption) ?[]const u8 {
        return (self.value);
    }

    pub fn getRemainTail(self: *ShortOption) ?[]const u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor = self.name.len;

        return self.name[self.cursor..];
    }

    pub fn getCurrentOptionAsStr(self: *ShortOption) []const u8 {
        return self.name[self.cursor - 1 .. self.cursor];
    }

    pub fn hasValue(self: *ShortOption) bool {
        return ((self.value != null) and (self.value.?.len >= 0));
    }

    pub fn hasTail(self: *ShortOption) bool {
        return (self.value == null and self.name.len > 1);
    }

    fn isAtEnd(self: *ShortOption) bool {
        return (self.cursor >= self.name.len);
    }
};

allocator: Allocator,
cmd: *const Command,
err: erro.Error,
tokenizer: Tokenizer,
args_ctx: ArgsContext,

pub fn init(allocator: Allocator, tokenizer: Tokenizer, command: *const Command) Parser {
    return Parser{
        .allocator = allocator,
        .cmd = command,
        .err = erro.Error.init(),
        .tokenizer = tokenizer,
        .args_ctx = ArgsContext.init(allocator),
    };
}

pub fn parse(self: *Parser) Error!ArgsContext {
    errdefer self.args_ctx.deinit();

    const takes_pos_args =
        (self.cmd.hasProperty(.takes_positional_arg) and self.cmd.countPositionalArgs() >= 1);
    var pos_args_idx: usize = 0;
    var parsed_all_pos_args = false;

    while (self.tokenizer.nextToken()) |*token| {
        if (mem.eql(u8, token.value, "help") or mem.eql(u8, token.value, "h")) {
            // Check whether help is enabled for `cmd`
            if (self.cmd.hasProperty(.enable_help)) {
                try self.putMatchedArg(&Arg.init("help", null), .none);
                break;
            } else {
                // Return error?
            }
        }

        if (token.isShortOption() or token.isLongOption()) {
            try self.parseOption(token);
            continue;
        }

        if (takes_pos_args and !parsed_all_pos_args) {
            try self.parseCommandArg(token, pos_args_idx);
            pos_args_idx += 1;
            parsed_all_pos_args = (pos_args_idx >= self.cmd.countPositionalArgs());
            continue;
        }
        try self.args_ctx.setSubcommand(
            try self.parseSubCommand(token.value),
        );
    }

    if (!(self.args_ctx.isPresent("help"))) {
        const takes_pos_args_and_is_required =
            (takes_pos_args and (self.cmd.hasProperty(.positional_arg_required)));

        if (takes_pos_args_and_is_required and !parsed_all_pos_args) {
            self.err.setContext(.{ .valid_cmd = self.cmd.name });
            return Error.CommandArgumentNotProvided;
        }

        if (self.cmd.hasProperty(.subcommand_required) and self.args_ctx.subcommand == null) {
            self.err.setContext(.{ .valid_cmd = self.cmd.name });
            return Error.CommandSubcommandNotProvided;
        }
    }
    return self.args_ctx;
}

fn parseCommandArg(self: *Parser, token: *const Token, pos_arg_idx: usize) Error!void {
    const arg = &self.cmd.positional_args.items[pos_arg_idx];

    if (arg.values_delimiter) |delimiter| {
        if (try self.splitValue(arg, token.value, delimiter)) |values| {
            return self.putMatchedArg(arg, .{ .many = values });
        }
    }
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    // TODO: This code and the code at line 262 is exactly same.
    // Either move it a function or do something about this.
    const num_values_to_consume = arg.max_values orelse arg.min_values orelse blk: {
        if (arg.hasProperty(.takes_multiple_values)) {
            try self.verifyAndAppendValue(arg, token.value, &values);
            try self.consumeValuesTillNextOption(arg, &values);
            return self.putMatchedArg(arg, .{ .many = values });
        }
        break :blk 1;
    };

    if (num_values_to_consume <= 1) {
        try self.verifyValue(arg, token.value);
        try self.putMatchedArg(arg, .{ .single = token.value });
        values.deinit();
        return;
    }
    try self.verifyAndAppendValue(arg, token.value, &values);
    try self.consumeNValues(arg, num_values_to_consume -% 1, &values);
    return self.putMatchedArg(arg, .{ .many = values });
}

fn parseOption(self: *Parser, token: *const Token) Error!void {
    if (token.isShortOption()) {
        try self.parseShortOption(token);
    } else if (token.isLongOption()) {
        try self.parseLongOption(token);
    }
}

fn parseShortOption(self: *Parser, token: *const Token) Error!void {
    const option_tuple = optionTokenToOptionTuple(token);
    var short_option = ShortOption.init(option_tuple[0], option_tuple[1]);

    while (short_option.next()) |option| {
        const arg = self.cmd.findShortOption(option) orelse {
            self.err.setContext(.{ .invalid_arg = short_option.getCurrentOptionAsStr() });
            return Error.UnknownFlag;
        };

        if (!(arg.hasProperty(.takes_value))) {
            if (short_option.hasValue()) {
                self.err.setContext(.{ .valid_arg = arg.name });
                return Error.UnneededAttachedValue;
            }
            try self.putMatchedArg(arg, .none);
            continue;
        }

        const value = short_option.getValue() orelse blk: {
            if (short_option.hasTail()) {
                // Take remain option/tail as value
                //
                // For ex: if -xyz is passed and -x takes value
                // take yz as value even if they are passed as options
                break :blk short_option.getRemainTail();
            } else {
                break :blk null;
            }
        };
        try self.parseOptionValue(arg, value);
    }
}

fn parseLongOption(self: *Parser, token: *const Token) Error!void {
    const option_tuple = optionTokenToOptionTuple(token);
    const arg = self.cmd.findLongOption(option_tuple[0]) orelse {
        self.err.setContext(.{ .invalid_arg = option_tuple[0] });
        return Error.UnknownFlag;
    };

    if (!(arg.hasProperty(.takes_value))) {
        if (option_tuple[1] != null) {
            self.err.setContext(.{ .valid_arg = option_tuple[0] });
            return Error.UnneededAttachedValue;
        } else {
            return self.putMatchedArg(arg, .none);
        }
    }
    return self.parseOptionValue(arg, option_tuple[1]);
}

// Converts a option token to a tuple holding a option name and an optional value
//
// --option, -f, -fgh                     => (option, null), (f, null), (fgh, null)
// --option=value, -f=value, -fgh=value   => (option, value), (f, value), (fgh, value)
// --option=, -f=, -fgh=                  => (option, ""), (f, ""), (fgh, "")
fn optionTokenToOptionTuple(token: *const Token) struct { []const u8, ?[]const u8 } {
    var kv_iter = mem.tokenize(u8, token.value, "=");

    return switch (token.tag) {
        .short_option,
        .short_option_with_tail,
        .long_option,
        => .{ token.value, null },

        .short_option_with_value,
        .short_option_with_empty_value,
        .short_options_with_value,
        .short_options_with_empty_value,
        .long_option_with_value,
        .long_option_with_empty_value,
        => .{ kv_iter.next().?, kv_iter.rest() },

        else => unreachable,
    };
}

fn parseOptionValue(self: *Parser, arg: *const Arg, attached_value: ?[]const u8) Error!void {
    if (attached_value) |value| {
        return self.parseAttachedValue(arg, value);
    }
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    const num_values_to_consume = arg.max_values orelse arg.min_values orelse blk: {
        if (arg.hasProperty(.takes_multiple_values)) {
            try self.consumeValuesTillNextOption(arg, &values);
            return self.putMatchedArg(arg, .{ .many = values });
        }
        break :blk 1;
    };
    try self.consumeNValues(arg, num_values_to_consume, &values);

    if (values.items.len == 0) {
        self.err.setContext(.{ .valid_arg = arg.name });
        return Error.ArgValueNotProvided;
    }
    if (values.items.len == 1) {
        const value = values.pop();
        try self.verifyValue(arg, value);
        try self.putMatchedArg(arg, .{ .single = value });

        values.deinit();
        return;
    }
    return self.putMatchedArg(arg, .{ .many = values });
}

fn parseAttachedValue(self: *Parser, arg: *const Arg, attached_value: []const u8) Error!void {
    if (arg.values_delimiter) |delimiter| {
        if (try self.splitValue(arg, attached_value, delimiter)) |values| {
            return self.putMatchedArg(arg, .{ .many = values });
        }
    }
    try self.verifyValue(arg, attached_value);
    try self.putMatchedArg(arg, .{ .single = attached_value });
}

fn splitValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    delimiter: []const u8,
) !(?std.ArrayList([]const u8)) {
    // zig fmt: off
    if (!(takesMorethanOneValue(arg))
        or !(mem.containsAtLeast(u8, value, 1, delimiter))) return null;
    // zig fmt: on

    var it = mem.split(u8, value, delimiter);
    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    while (it.next()) |val| {
        try self.verifyAndAppendValue(arg, val, &values);
    }
    return values;
}

fn consumeNValues(
    self: *Parser,
    arg: *const Arg,
    num: usize,
    list: *std.ArrayList([]const u8),
) Error!void {
    var i: usize = 1;
    while (i <= num) : (i += 1) {
        const value = self.tokenizer.nextNonOptionArg() orelse return;
        try self.verifyAndAppendValue(arg, value, list);
    }
}

fn consumeValuesTillNextOption(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
) Error!void {
    while (self.tokenizer.nextNonOptionArg()) |value| {
        try self.verifyAndAppendValue(arg, value, list);
    }
}

fn verifyAndAppendValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    list: *std.ArrayList([]const u8),
) Error!void {
    try self.verifyValue(arg, value);
    try list.append(value);
}

fn verifyValue(self: *Parser, arg: *const Arg, value: []const u8) Error!void {
    self.err.setContext(.{ .valid_arg = arg.name });

    if ((value.len == 0) and !(arg.hasProperty(.allow_empty_value)))
        return Error.EmptyArgValueNotAllowed;

    if (!(arg.isValidValue(value))) {
        self.err.setContext(.{ .invalid_value = value, .valid_values = arg.allowed_values.? });
        return Error.ProvidedValueIsNotValidOption;
    }
}

fn putMatchedArg(self: *Parser, arg: *const Arg, value: args_context.MatchedArgValue) Error!void {
    errdefer if (value.isMany()) value.many.deinit();
    try self.verifyValuesLength(arg, value.count());

    var ctx = &self.args_ctx;
    var maybe_old_value = ctx.args.getPtr(arg.name);

    if (maybe_old_value) |old_value| {
        // To fix the const error
        var new_value = value;

        switch (old_value.*) {
            .none => if (!(new_value.isNone())) {
                return ctx.args.put(arg.name, new_value);
            },
            .single => |old_single_value| {
                if (new_value.isSingle()) {
                    // If both old and new value are single then
                    // store them in a single ArrayList and create a new key
                    var many = std.ArrayList([]const u8).init(self.allocator);
                    try many.append(old_single_value);
                    try many.append(new_value.single);

                    return ctx.args.put(arg.name, .{ .many = many });
                } else if (new_value.isMany()) {
                    // If old value is single but the new value is many then
                    // append the old one into new many value
                    try new_value.many.append(old_single_value);
                    return ctx.args.put(arg.name, new_value);
                }
            },
            .many => |*old_many_values| {
                if (new_value.isSingle()) {
                    // If old value is many and the new value is single then
                    // append the new single value into old many value
                    try old_many_values.append(new_value.single);
                } else if (new_value.isMany()) {
                    // If both old and new value is many, append all new values into old value
                    try old_many_values.appendSlice(try new_value.many.toOwnedSlice());
                }
            },
        }
    } else {
        // We don't have old value, put the new value
        return ctx.args.put(arg.name, value);
    }
}

fn verifyValuesLength(self: *Parser, arg: *const Arg, len: usize) Error!void {
    if ((len > 1) and !(takesMorethanOneValue(arg))) {
        self.err.setContext(.{ .valid_arg = arg.name, .max_num_values = 1 });
        return Error.TooManyArgValue;
    }
    if ((arg.min_values != null) and (len < arg.min_values.?)) {
        self.err.setContext(.{ .valid_arg = arg.name, .min_num_values = arg.min_values.? });
        return Error.TooFewArgValue;
    }

    if ((arg.max_values != null) and (len > arg.max_values.?)) {
        self.err.setContext(.{ .valid_arg = arg.name, .max_num_values = arg.max_values.? });
        return Error.TooManyArgValue;
    }
}

fn takesMorethanOneValue(arg: *const Arg) bool {
    const num_values = arg.max_values orelse arg.min_values orelse 1;
    return ((num_values > 1) or (arg.hasProperty(.takes_multiple_values)));
}

fn parseSubCommand(self: *Parser, provided_subcmd: []const u8) Error!MatchedSubCommand {
    const subcmd = self.cmd.findSubcommand(provided_subcmd) orelse {
        self.err.setContext(.{ .invalid_arg = provided_subcmd });
        return Error.UnknownCommand;
    };
    // zig fmt: off
    const takes_value = subcmd.hasProperty(.takes_positional_arg)
        or (subcmd.countPositionalArgs() >= 1)
        or (subcmd.countOptions() >= 1)
        or (subcmd.countSubcommands() >= 1);
    // zig fmt: on

    if (!takes_value) {
        return MatchedSubCommand.init(subcmd.name, null);
    }

    const args = self.tokenizer.restArg() orelse {
        if (subcmd.hasProperty(.positional_arg_required)) {
            self.err.setContext(.{ .valid_cmd = provided_subcmd });
            return Error.CommandArgumentNotProvided;
        }
        return MatchedSubCommand.init(
            subcmd.name,
            ArgsContext.init(self.allocator),
        );
    };
    var parser = Parser.init(self.allocator, Tokenizer.init(args), subcmd);
    const subcmd_ctx = parser.parse() catch |err| {
        // Bubble up the error trace to the parent command that happened while parsing subcommand
        //self.err_builder = parser.err_builder;
        self.err = parser.err;
        return err;
    };

    return MatchedSubCommand.init(subcmd.name, subcmd_ctx);
}
