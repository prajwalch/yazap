const Parser = @This();

const std = @import("std");
const ArgsContext = @import("ArgsContext.zig");
const Command = @import("../Command.zig");
const Arg = @import("../Arg.zig");
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

const mem = std.mem;
const Allocator = std.mem.Allocator;
const FlagTuple = std.meta.Tuple(&[_]type{ []const u8, ?[]const u8 });
const MatchedArg = ArgsContext.MatchedArg;
const MatchedSubCommand = ArgsContext.MatchedSubCommand;

pub const Error = error{
    UnknownFlag,
    UnknownCommand,
    CommandArgumentNotProvided,
    CommandSubcommandNotProvided,
    FlagValueNotProvided,
    UnneededAttachedValue,
    UnneededEmptyAttachedValue,
    EmptyFlagValueNotAllowed,
    ProvidedValueIsNotValidOption,
} || Allocator.Error;

const InternalError = error{
    ArgValueNotProvided,
    EmptyArgValueNotAllowed,
} || Error;

const ShortFlag = struct {
    name: []const u8,
    value: ?[]const u8,
    cursor: usize,

    pub fn init(name: []const u8, value: ?[]const u8) ShortFlag {
        return ShortFlag{
            .name = name,
            .value = value,
            .cursor = 0,
        };
    }

    pub fn next(self: *ShortFlag) ?u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor += 1;

        return self.name[self.cursor];
    }

    pub fn getValue(self: *ShortFlag) ?[]const u8 {
        return (self.value);
    }

    pub fn getRemainTail(self: *ShortFlag) ?[]const u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor = self.name.len;

        return self.name[self.cursor..];
    }

    pub fn hasValue(self: *ShortFlag) bool {
        if (self.value) |v| {
            return (v.len >= 1);
        } else {
            return false;
        }
    }

    pub fn hasEmptyValue(self: *ShortFlag) bool {
        if (self.value) |v| {
            return (v.len == 0);
        } else {
            return false;
        }
    }

    pub fn hasTail(self: *ShortFlag) bool {
        return (self.value == null and self.name.len > 1);
    }

    fn isAtEnd(self: *ShortFlag) bool {
        return (self.cursor >= self.name.len);
    }
};

allocator: Allocator,
tokenizer: Tokenizer,
cmd: *const Command,

pub fn init(
    allocator: Allocator,
    tokenizer: Tokenizer,
    command: *const Command,
) Parser {
    return Parser{
        .allocator = allocator,
        .tokenizer = tokenizer,
        .cmd = command,
    };
}

pub fn parse(self: *Parser) Error!ArgsContext {
    var args_ctx = ArgsContext.init(self.allocator);
    errdefer args_ctx.deinit();

    try self.parseCommandArgument(&args_ctx);

    while (self.tokenizer.nextToken()) |*token| {
        if (token.isShortFlag() or token.isLongFlag()) {
            if (self.cmd.args.items.len == 0)
                return Error.UnknownFlag;

            self.parseArg(token, &args_ctx) catch |err| switch (err) {
                InternalError.ArgValueNotProvided => return Error.FlagValueNotProvided,
                InternalError.EmptyArgValueNotAllowed => return Error.EmptyFlagValueNotAllowed,
                else => |e| return e,
            };
        } else {
            if (self.cmd.subcommands.items.len == 0)
                return Error.UnknownCommand;

            const subcmd = try self.parseSubCommand(token.value);
            try args_ctx.setSubcommand(subcmd);
        }
    }

    if (self.cmd.setting.subcommand_required and args_ctx.subcommand == null) {
        return Error.CommandSubcommandNotProvided;
    }
    return args_ctx;
}

fn parseCommandArgument(self: *Parser, args_ctx: *ArgsContext) Error!void {
    if (self.cmd.setting.takes_value) {
        for (self.cmd.args.items) |arg| {
            if ((arg.short_name == null) and (arg.long_name == null)) {
                var parsed_arg = self.consumeArgValue(&arg, null) catch |err| switch (err) {
                    InternalError.ArgValueNotProvided,
                    InternalError.EmptyArgValueNotAllowed,
                    => break,
                    else => |e| return e,
                };
                try args_ctx.putMatchedArg(parsed_arg);
            }
        }

        if (self.cmd.setting.arg_required and (args_ctx.args.count() == 0)) {
            return Error.CommandArgumentNotProvided;
        }
    }
}

fn parseArg(self: *Parser, token: *Token, args_ctx: *ArgsContext) InternalError!void {
    if (token.isShortFlag()) {
        const parsed_args = try self.parseShortArg(token);

        for (parsed_args) |parsed_arg| {
            try args_ctx.putMatchedArg(parsed_arg);
        }
    } else if (token.isLongFlag()) {
        const parsed_arg = try self.parseLongArg(token);
        try args_ctx.putMatchedArg(parsed_arg);
    }
}

fn parseShortArg(self: *Parser, token: *Token) InternalError![]const MatchedArg {
    const flag_tuple = flagTokenToFlagTuple(token);
    var short_flag = ShortFlag.init(flag_tuple.@"0", flag_tuple.@"1");
    var parsed_args = std.ArrayList(MatchedArg).init(self.allocator);
    errdefer parsed_args.deinit();

    while (short_flag.next()) |flag| {
        const arg = self.cmd.findArgByShortName(flag) orelse {
            return Error.UnknownFlag;
        };

        if (!(arg.settings.takes_value)) {
            if (short_flag.hasValue()) {
                return Error.UnneededAttachedValue;
            } else if (short_flag.hasEmptyValue()) {
                return Error.UnneededEmptyAttachedValue;
            } else {
                try parsed_args.append(MatchedArg.initWithoutValue(arg.name));
                continue;
            }
        }

        const value = short_flag.getValue() orelse blk: {
            if (short_flag.hasTail()) {
                // Take remain flag/tail as value
                //
                // For ex: if -xyz is passed and -x takes value
                // take yz as value even if they are passed as flags
                break :blk short_flag.getRemainTail();
            } else {
                break :blk null;
            }
        };
        const parsed_arg = try self.consumeArgValue(arg, value);
        try parsed_args.append(parsed_arg);
    }
    return parsed_args.toOwnedSlice();
}

fn parseLongArg(self: *Parser, token: *Token) InternalError!MatchedArg {
    const flag_tuple = flagTokenToFlagTuple(token);
    const arg = self.cmd.findArgByLongName(flag_tuple.@"0") orelse {
        return Error.UnknownFlag;
    };

    if (!(arg.settings.takes_value)) {
        if (flag_tuple.@"1" != null) {
            return Error.UnneededAttachedValue;
        } else {
            return MatchedArg.initWithoutValue(arg.name);
        }
    }
    const parsed_arg = try self.consumeArgValue(arg, flag_tuple.@"1");
    return parsed_arg;
}

// Converts a flag token to a tuple holding a flag name and an optional value
//
// --flag, -f, -fgh                     => (flag, null), (f, null), (fgh, null)
// --flag=value, -f=value, -fgh=value   => (flag, value), (f, value), (fgh, value)
// --flag=, -f=, -fgh=                  => (flag, ""), (f, ""), (fgh, "")
fn flagTokenToFlagTuple(token: *Token) FlagTuple {
    var kv_iter = mem.tokenize(u8, token.value, "=");

    return switch (token.tag) {
        .short_flag,
        .short_flag_with_tail,
        .long_flag,
        => .{ token.value, null },

        .short_flag_with_value,
        .short_flag_with_empty_value,
        .short_flags_with_value,
        .short_flags_with_empty_value,
        .long_flag_with_value,
        .long_flag_with_empty_value,
        => .{ kv_iter.next().?, kv_iter.rest() },

        else => unreachable,
    };
}

fn consumeArgValue(
    self: *Parser,
    arg: *const Arg,
    attached_value: ?[]const u8,
) InternalError!MatchedArg {
    if (attached_value) |val| {
        return self.processValue(arg, val, true);
    } else {
        const value = self.tokenizer.nextNonFlagArg() orelse return InternalError.ArgValueNotProvided;
        return self.processValue(arg, value, false);
    }
}

fn processValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    is_attached_value: bool,
) InternalError!MatchedArg {
    if (arg.values_delimiter) |delimiter| {
        var values_iter = mem.split(u8, value, delimiter);
        var values = std.ArrayList([]const u8).init(self.allocator);
        errdefer values.deinit();

        while (values_iter.next()) |val| {
            const _val = @as([]const u8, val);

            if ((_val.len == 0) and !(arg.settings.allow_empty_value))
                return InternalError.EmptyArgValueNotAllowed;
            if (!arg.verifyValueInAllowedValues(_val))
                return InternalError.ProvidedValueIsNotValidOption;

            try values.append(_val);
        }

        // zig fmt: off
        if (mem.containsAtLeast(u8, value, 1, delimiter)
            or arg.remainingValuesToConsume(values.items.len) == 0) {
            // zig fmt: on
            return MatchedArg.initWithManyValues(arg.name, values);
        } else {
            values.deinit();
        }
    }

    if (is_attached_value) {
        // Ignore multiples values seperated with delimiter
        // if have
        //
        // For ex: -f=v1,v2
        // flag = f
        // value = v1,v2
        return MatchedArg.initWithSingleValue(arg.name, value);
    } else {
        // we have given only one value hence we pass 1 here
        const num_remaining_values = arg.remainingValuesToConsume(1);

        if (num_remaining_values == 0) {
            return MatchedArg.initWithSingleValue(arg.name, value);
        } else {
            var index: usize = 1;
            var values = std.ArrayList([]const u8).init(self.allocator);
            errdefer values.deinit();

            try values.append(value);

            // consume each value using tokenizer
            while (index <= num_remaining_values) : (index += 1) {
                const _value = self.tokenizer.nextNonFlagArg() orelse break;

                if ((_value.len == 0) and !(arg.settings.allow_empty_value))
                    return InternalError.EmptyArgValueNotAllowed;
                if (!arg.verifyValueInAllowedValues(_value))
                    return InternalError.ProvidedValueIsNotValidOption;

                try values.append(_value);
            }
            return MatchedArg.initWithManyValues(arg.name, values);
        }
    }
}

fn parseSubCommand(
    self: *Parser,
    provided_subcmd: []const u8,
) Error!MatchedSubCommand {
    for (self.cmd.subcommands.items) |valid_subcmd| {
        if (mem.eql(u8, valid_subcmd.name, provided_subcmd)) {
            // zig fmt: off
            if (valid_subcmd.setting.takes_value
                or valid_subcmd.args.items.len >= 1
                or valid_subcmd.subcommands.items.len >= 1) {
                // zig fmt: on
                const subcmd_argv = self.tokenizer.restArg() orelse return Error.CommandArgumentNotProvided;
                var parser = Parser.init(self.allocator, Tokenizer.init(subcmd_argv), &valid_subcmd);
                const subcmd_ctx = try parser.parse();

                return MatchedSubCommand.initWithArg(valid_subcmd.name, subcmd_ctx);
            }
            return MatchedSubCommand.initWithoutArg(valid_subcmd.name);
        }
    }
    return Error.UnknownCommand;
}
