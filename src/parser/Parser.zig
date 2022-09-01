const Parser = @This();

const std = @import("std");
const ArgsContext = @import("ArgsContext.zig");
const ErrorContext = @import("ErrorContext.zig");
const Command = @import("../Command.zig");
const Arg = @import("../Arg.zig");
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

const mem = std.mem;
const Allocator = std.mem.Allocator;
const FlagTuple = std.meta.Tuple(&[_]type{ []const u8, ?[]const u8 });
const MatchedArgValue = ArgsContext.MatchedArgValue;
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
    TooManyArgValue,
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

    pub fn next(self: *ShortFlag) ?*const u8 {
        if (self.isAtEnd()) return null;
        defer self.cursor += 1;

        return &self.name[self.cursor];
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
args_ctx: ArgsContext,
err_ctx: ErrorContext,
cmd: *const Command,

pub fn init(
    allocator: Allocator,
    tokenizer: Tokenizer,
    command: *const Command,
) Parser {
    return Parser{
        .allocator = allocator,
        .tokenizer = tokenizer,
        .args_ctx = ArgsContext.init(allocator),
        .err_ctx = ErrorContext.init(),
        .cmd = command,
    };
}

pub fn parse(self: *Parser) Error!ArgsContext {
    errdefer self.args_ctx.deinit();

    self.err_ctx.setCmd(self.cmd);
    try self.parseCommandArgument();

    while (self.tokenizer.nextToken()) |*token| {
        self.err_ctx.setProvidedArg(token.value);

        if (token.isShortFlag() or token.isLongFlag()) {
            if (self.cmd.countArgs() == 0) {
                self.err_ctx.setErr(Error.UnknownFlag);
                return self.err_ctx.err;
            }

            self.parseArg(token) catch |err| switch (err) {
                InternalError.ArgValueNotProvided => {
                    self.err_ctx.setErr(Error.FlagValueNotProvided);
                    return self.err_ctx.err;
                },
                InternalError.EmptyArgValueNotAllowed => {
                    self.err_ctx.setErr(Error.EmptyFlagValueNotAllowed);
                    return self.err_ctx.err;
                },
                else => |e| {
                    self.err_ctx.setErr(e);
                    return e;
                },
            };
        } else {
            if (self.cmd.countSubcommands() == 0) {
                self.err_ctx.setErr(Error.UnknownCommand);
                return Error.UnknownCommand;
            }

            const subcmd = try self.parseSubCommand(token.value);
            try self.args_ctx.setSubcommand(subcmd);
        }
    }

    if (self.cmd.setting.subcommand_required and self.args_ctx.subcommand == null) {
        self.err_ctx.setErr(Error.CommandSubcommandNotProvided);
        return self.err_ctx.err;
    }
    return self.args_ctx;
}

fn parseCommandArgument(self: *Parser) Error!void {
    if (!self.cmd.setting.takes_value) return;

    for (self.cmd.args.items) |arg| {
        if ((arg.short_name == null) and (arg.long_name == null)) {
            self.consumeArgValue(&arg, null) catch |err| switch (err) {
                InternalError.ArgValueNotProvided,
                InternalError.EmptyArgValueNotAllowed,
                => break,
                else => |e| {
                    self.err_ctx.setErr(e);
                    return e;
                },
            };
        }
    }

    if (self.cmd.setting.arg_required and (self.args_ctx.args.count() == 0)) {
        self.err_ctx.setErr(Error.CommandArgumentNotProvided);
        return self.err_ctx.err;
    }
}

fn parseArg(self: *Parser, token: *const Token) InternalError!void {
    if (token.isShortFlag()) {
        try self.parseShortArg(token);
    } else if (token.isLongFlag()) {
        try self.parseLongArg(token);
    }
}

fn parseShortArg(self: *Parser, token: *const Token) InternalError!void {
    const flag_tuple = flagTokenToFlagTuple(token);
    var short_flag = ShortFlag.init(flag_tuple.@"0", flag_tuple.@"1");

    while (short_flag.next()) |flag| {
        self.err_ctx.setProvidedArg(@as(*const [1]u8, flag));

        const arg = self.cmd.findArgByShortName(flag.*) orelse {
            return Error.UnknownFlag;
        };
        self.err_ctx.setArg(arg);

        if (!(arg.settings.takes_value)) {
            if (short_flag.hasValue()) {
                return Error.UnneededAttachedValue;
            } else if (short_flag.hasEmptyValue()) {
                return Error.UnneededEmptyAttachedValue;
            } else {
                try self.args_ctx.putMatchedArg(arg, MatchedArgValue.initNone());
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
        try self.consumeArgValue(arg, value);
    }
}

fn parseLongArg(self: *Parser, token: *const Token) InternalError!void {
    const flag_tuple = flagTokenToFlagTuple(token);
    self.err_ctx.setProvidedArg(flag_tuple.@"0");

    const arg = self.cmd.findArgByLongName(flag_tuple.@"0") orelse {
        return Error.UnknownFlag;
    };
    self.err_ctx.setArg(arg);

    if (!(arg.settings.takes_value)) {
        if (flag_tuple.@"1" != null) {
            return Error.UnneededAttachedValue;
        } else {
            return self.args_ctx.putMatchedArg(arg, MatchedArgValue.initNone());
        }
    }
    return self.consumeArgValue(arg, flag_tuple.@"1");
}

// Converts a flag token to a tuple holding a flag name and an optional value
//
// --flag, -f, -fgh                     => (flag, null), (f, null), (fgh, null)
// --flag=value, -f=value, -fgh=value   => (flag, value), (f, value), (fgh, value)
// --flag=, -f=, -fgh=                  => (flag, ""), (f, ""), (fgh, "")
fn flagTokenToFlagTuple(token: *const Token) FlagTuple {
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
) InternalError!void {
    // Only set arg if caller didn't set it already
    if (self.err_ctx.arg == null) self.err_ctx.setArg(arg);

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
) InternalError!void {
    self.err_ctx.setProvidedArg(value);

    if (arg.values_delimiter) |delimiter| {
        if (mem.containsAtLeast(u8, value, 1, delimiter)) {
            var values_iter = mem.split(u8, value, delimiter);
            var values = std.ArrayList([]const u8).init(self.allocator);
            errdefer values.deinit();

            while (values_iter.next()) |val| {
                try self.verifyAndAppendValue(arg, &values, val);
            }
            return self.args_ctx.putMatchedArg(arg, MatchedArgValue.initMany(values));
        }
    }

    if (is_attached_value) {
        // When values delimiter is not set and multiple values are passed
        // by attaching it then take the entire values as single value
        //
        // For ex: -f=v1,v2
        // flag = f
        // value = v1,v2
        if (arg.verifyValueInAllowedValues(value)) {
            return self.args_ctx.putMatchedArg(arg, MatchedArgValue.initSingle(value));
        } else {
            return InternalError.ProvidedValueIsNotValidOption;
        }
    } else {
        const num_remaining_values = arg.remainingValuesToConsume(&self.args_ctx);

        if (num_remaining_values <= 1) {
            if (arg.verifyValueInAllowedValues(value)) {
                return self.args_ctx.putMatchedArg(arg, MatchedArgValue.initSingle(value));
            } else {
                return InternalError.ProvidedValueIsNotValidOption;
            }
        } else {
            var index: usize = 1;
            var values = std.ArrayList([]const u8).init(self.allocator);
            errdefer values.deinit();

            try values.append(value);
            index += 1;

fn verifyAndAppendValue(
    self: *Parser,
    arg: *const Arg,
    list: *std.ArrayList([]const u8),
    value: []const u8,
) InternalError!void {
    self.err_ctx.setProvidedArg(value);

    if ((value.len == 0) and !(arg.settings.allow_empty_value))
        return InternalError.EmptyArgValueNotAllowed;
    if (!(arg.verifyValueInAllowedValues(value)))
        return InternalError.ProvidedValueIsNotValidOption;

    try list.append(value);
}

fn parseSubCommand(
    self: *Parser,
    provided_subcmd: []const u8,
) Error!MatchedSubCommand {
    const valid_subcmd = self.cmd.findSubcommand(provided_subcmd) orelse {
        self.err_ctx.setErr(Error.UnknownCommand);
        return self.err_ctx.err;
    };

    // zig fmt: off
    if (valid_subcmd.setting.takes_value
        or valid_subcmd.args.items.len >= 1
        or valid_subcmd.subcommands.items.len >= 1) {
        // zig fmt: on
        const subcmd_argv = self.tokenizer.restArg() orelse {
            self.err_ctx.setErr(Error.CommandArgumentNotProvided);
            return self.err_ctx.err;
        };
        var parser = Parser.init(self.allocator, Tokenizer.init(subcmd_argv), valid_subcmd);
        const subcmd_ctx = try parser.parse();

        return MatchedSubCommand.initWithArg(valid_subcmd.name, subcmd_ctx);
    }
    return MatchedSubCommand.initWithoutArg(valid_subcmd.name);
}
