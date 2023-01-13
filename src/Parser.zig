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
const OptionTuple = std.meta.Tuple(&[_]type{ []const u8, ?[]const u8 });
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

    pub fn next(self: *ShortOption) ?*const u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor += 1;

        return &self.name[self.cursor];
    }

    pub fn getValue(self: *ShortOption) ?[]const u8 {
        return (self.value);
    }

    pub fn getRemainTail(self: *ShortOption) ?[]const u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor = self.name.len;

        return self.name[self.cursor..];
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
cmd_args_idx: usize,
parse_cmd_args: bool,

pub fn init(allocator: Allocator, tokenizer: Tokenizer, command: *const Command) Parser {
    return Parser{
        .allocator = allocator,
        .cmd = command,
        .err = erro.Error.init(),
        .tokenizer = tokenizer,
        .args_ctx = ArgsContext.init(allocator),
        .cmd_args_idx = 0,
        .parse_cmd_args = (command.isSettingApplied(.takes_value) and command.countArgs() >= 1),
    };
}

pub fn parse(self: *Parser) Error!ArgsContext {
    errdefer self.args_ctx.deinit();

    while (self.tokenizer.nextToken()) |*token| {
        if (mem.eql(u8, token.value, "help") or mem.eql(u8, token.value, "h")) {
            // Check whether help is enabled for `cmd`
            if (self.cmd.isSettingApplied(.enable_help)) {
                try self.putMatchedArg(&Arg.new("help", null), .none);
                break;
            } else {
                // Return error?
            }
        }

        if (self.parse_cmd_args) {
            try self.parseCommandArg(token);
            // Skip current token if it has been consumed otherwise further process it
            if (self.parse_cmd_args) continue;
        }

        if (!token.isShortOption() and !token.isLongOption()) {
            try self.args_ctx.setSubcommand(
                try self.parseSubCommand(token.value),
            );
            continue;
        }
        try self.parseOption(token);
    }

    if (!(self.args_ctx.isPresent("help"))) {
        if (self.cmd.isSettingApplied(.subcommand_required) and self.args_ctx.subcommand == null) {
            self.err.setContext(.{ .valid_cmd = self.cmd.name });
            return Error.CommandSubcommandNotProvided;
        }
    }
    return self.args_ctx;
}

fn parseCommandArg(self: *Parser, token: *const Token) Error!void {
    // All the arguments are parsed
    if (self.cmd_args_idx >= self.cmd.countArgs()) {
        self.parse_cmd_args = false;
        return;
    }
    // we found a option
    if (token.tag != .some_argument) {
        if (self.cmd.isSettingApplied(.arg_required) and (self.args_ctx.args.count() == 0)) {
            self.err.setContext(.{ .valid_cmd = self.cmd.name });
            return Error.CommandArgumentNotProvided;
        } else {
            self.parse_cmd_args = false;
            return;
        }
    }
    const arg = &self.cmd.args.items[self.cmd_args_idx];
    defer self.cmd_args_idx += 1;

    self.processValue(arg, token.value, false) catch |err| switch (err) {
        Error.ArgValueNotProvided,
        Error.EmptyArgValueNotAllowed,
        => return,
        else => |e| return e,
    };
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
        const arg = self.cmd.findShortOption(option.*) orelse {
            self.err.setContext(.{ .invalid_arg = @as(*const [1]u8, option) });
            return Error.UnknownFlag;
        };

        if (!(arg.isSettingApplied(.takes_value))) {
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

    if (!(arg.isSettingApplied(.takes_value))) {
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
fn optionTokenToOptionTuple(token: *const Token) OptionTuple {
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
    if (attached_value) |val| {
        return self.processValue(arg, val, true);
    } else {
        const value = self.tokenizer.nextNonOptionArg() orelse {
            self.err.setContext(.{ .valid_arg = arg.name });
            return Error.ArgValueNotProvided;
        };
        return self.processValue(arg, value, false);
    }
}

fn processValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    is_attached_value: bool,
) Error!void {
    if (arg.values_delimiter) |delimiter| {
        if (mem.containsAtLeast(u8, value, 1, delimiter)) {
            var values_iter = mem.split(u8, value, delimiter);
            var values = std.ArrayList([]const u8).init(self.allocator);
            errdefer values.deinit();

            while (values_iter.next()) |val| {
                try self.verifyAndAppendValue(arg, &values, val);
            }
            return self.putMatchedArg(arg, .{ .many = values });
        }
    }

    if (is_attached_value) {
        // When values delimiter is not set and multiple values are passed
        // by attaching it then take the entire values as single value
        //
        // For ex: -f=v1,v2
        // option = f
        // value = v1,v2
        if (!arg.verifyValueInAllowedValues(value)) {
            self.err.setContext(.{ .valid_arg = arg.name, .invalid_value = value });
            return Error.ProvidedValueIsNotValidOption;
        }
        return self.putMatchedArg(arg, .{ .single = value });
    }

    var values = std.ArrayList([]const u8).init(self.allocator);
    errdefer values.deinit();

    try self.verifyAndAppendValue(arg, &values, value);
    // Consume minimum number of required values first
    if (arg.min_values) |min| {
        try self.consumeNValues(arg, &values, min);
    }
    const has_max_num = (arg.max_values != null);
    const max_eqls_one = (has_max_num and (arg.max_values.? == 1));

    // If maximum number and takes_multiple_values is not set we are not looking for more values
    if ((!has_max_num or max_eqls_one) and !(arg.isSettingApplied(.takes_multiple_values))) {
        // If values contains only one value, we can be sure that the minimum number of values is set to 1
        // therefore return it as a single value instead
        if (values.items.len == 1) {
            values.deinit();
            return self.putMatchedArg(arg, .{ .single = value });
        }
        return self.putMatchedArg(arg, .{ .many = values });
    }
    if (has_max_num) {
        try self.consumeNValues(arg, &values, arg.max_values.?);
        return self.putMatchedArg(arg, .{ .many = values });
    }
    if (arg.isSettingApplied(.takes_multiple_values)) {
        try self.consumeValuesTillNextOption(arg, &values);
        return self.putMatchedArg(arg, .{ .many = values });
    }
}

fn consumeNValues(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
    num: usize,
) Error!void {
    var i: usize = 1;
    while (i < num) : (i += 1) {
        const value = self.tokenizer.nextNonOptionArg() orelse return;
        try self.verifyAndAppendValue(arg, list, value);
    }
}

fn consumeValuesTillNextOption(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
) Error!void {
    while (self.tokenizer.nextNonOptionArg()) |value| {
        try self.verifyAndAppendValue(arg, list, value);
    }
}

fn verifyAndAppendValue(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
    value: []const u8,
) Error!void {
    self.err.setContext(.{ .valid_arg = arg.name });

    if ((arg.max_values != null) and (list.items.len >= arg.max_values.?)) {
        self.err.setContext(.{ .max_num_values = arg.max_values.? });
        return Error.TooManyArgValue;
    }

    if ((value.len == 0) and !(arg.isSettingApplied(.allow_empty_value)))
        return Error.EmptyArgValueNotAllowed;

    if (!(arg.verifyValueInAllowedValues(value))) {
        self.err.setContext(.{ .valid_values = arg.allowed_values.? });
        return Error.ProvidedValueIsNotValidOption;
    }
    try list.append(value);
}

fn parseSubCommand(self: *Parser, provided_subcmd: []const u8) Error!MatchedSubCommand {
    const subcmd = self.cmd.findSubcommand(provided_subcmd) orelse {
        self.err.setContext(.{ .invalid_arg = provided_subcmd });
        return Error.UnknownCommand;
    };
    // zig fmt: off
    const takes_value = subcmd.isSettingApplied(.takes_value)
        or (subcmd.countArgs() >= 1)
        or (subcmd.countOptions() >= 1)
        or (subcmd.countSubcommands() >= 1);
    // zig fmt: on

    if (!takes_value) {
        return MatchedSubCommand.init(subcmd.name, null);
    }

    const args = self.tokenizer.restArg() orelse {
        if (subcmd.isSettingApplied(.arg_required)) {
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

fn putMatchedArg(self: *Parser, arg: *const Arg, value: args_context.MatchedArgValue) Error!void {
    if ((arg.min_values != null) and (value.count() < arg.min_values.?)) {
        self.err.setContext(.{ .valid_arg = arg.name, .min_num_values = arg.min_values.? });
        return Error.TooFewArgValue;
    }

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
                    try old_many_values.appendSlice(new_value.many.toOwnedSlice());
                }
            },
        }
    } else {
        // We don't have old value, put the new value
        return ctx.args.put(arg.name, value);
    }
}
