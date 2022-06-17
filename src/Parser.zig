const Parser = @This();

const std = @import("std");
const arg_matches = @import("arg_matches.zig");
const tokenizer = @import("tokenizer.zig");
const Command = @import("Command.zig");
const Arg = @import("Arg.zig");
const MatchedArg = @import("MatchedArg.zig");

const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArgMatches = arg_matches.ArgMatches;
const Token = tokenizer.Token;
const Tokenizer = tokenizer.Tokenizer;

// TODO: Clean up errors
pub const Error = error{
    UnknownArg,
    UnknownCommand,
    UnknownFlag,
    CommandArgumentNotProvided,
    MissingCommandSubCommand,
    ValueIsNotInAllowedValues,
    UnneededAttachedValue,
    UnneededEmptyAttachedValue,
    ArgValueNotProvided,
    EmptyArgValueNotAllowed,
} || Allocator.Error;

const InternalError = error{
    AttachedValueNotConsumed,
} || Error;

allocator: Allocator,
tokenizer: Tokenizer,
cmd: *const Command,

pub fn init(
    allocator: Allocator,
    argv: []const [:0]const u8,
    command: *const Command,
) Parser {
    return Parser{
        .allocator = allocator,
        .tokenizer = Tokenizer.init(argv),
        .cmd = command,
    };
}

pub fn parse(self: *Parser) Error!ArgMatches {
    var matches = ArgMatches.init(self.allocator);
    errdefer matches.deinit();

    if (self.cmd.setting.takes_value) {
        for (self.cmd.args.items) |arg| {
            if ((arg.short_name == null) and (arg.long_name == null)) {
                var parsed_arg = self.consumeArgValue(&arg, null) catch |err| switch (err) {
                    InternalError.AttachedValueNotConsumed => unreachable,
                    InternalError.ArgValueNotProvided => break,
                    else => |e| return e,
                };
                try matches.putMatchedArg(parsed_arg);
            }
        }

        if (self.cmd.setting.arg_required and (matches.args.count() == 0)) {
            return Error.CommandArgumentNotProvided;
        }
    }

    while (self.tokenizer.nextToken()) |*token| {
        if (token.isShortFlag() or token.isLongFlag()) {
            if (self.cmd.args.items.len == 0)
                return Error.UnknownArg;

            try self.parseArg(token, &matches);
        } else {
            if (self.cmd.subcommands.items.len == 0)
                return Error.UnknownCommand;

            const subcmd = try self.parseSubCommand(token.value);
            try matches.setSubcommand(subcmd);
        }
    }

    if (self.cmd.setting.subcommand_required and matches.subcommand == null) {
        return Error.MissingCommandSubCommand;
    }

    return matches;
}

pub fn parseArg(self: *Parser, token: *Token, matches: *ArgMatches) Error!void {
    if (token.isShortFlag()) {
        const parsed_args = try self.parseShortArg(token);

        for (parsed_args) |parsed_arg| {
            try matches.putMatchedArg(parsed_arg);
        }
    } else if (token.isLongFlag()) {
        const parsed_arg = try self.parseLongArg(token);
        try matches.putMatchedArg(parsed_arg);
    }
}

fn parseShortArg(self: *Parser, token: *Token) Error![]const MatchedArg {
    var short_flag = ShortFlag.initFromToken(token);
    var parsed_args = std.ArrayList(MatchedArg).init(self.allocator);
    errdefer parsed_args.deinit();

    while (short_flag.next()) |flag| {
        const arg = findArgByShortName(self.cmd.args.items, flag) orelse {
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

fn findArgByShortName(valid_args: []const Arg, short_name: u8) ?*const Arg {
    for (valid_args) |*valid_arg| {
        if (valid_arg.short_name) |valid_short_name| {
            if (valid_short_name == short_name) return valid_arg;
        }
    }
    return null;
}

fn parseLongArg(self: *Parser, token: *Token) Error!MatchedArg {
    const flag_tuple = flagTokenToFlagTuple(token);
    const arg = findArgByLongName(self.cmd.args.items, flag_tuple.@"0") orelse {
        return Error.UnknownFlag;
    };

    if (!arg.settings.takes_value) {
        if (flag_tuple.@"1" != null) {
            return Error.UnneededAttachedValue;
        } else {
            return MatchedArg.initWithoutValue(arg.name);
        }
    }

    const parsed_arg = try self.consumeArgValue(arg, flag_tuple.@"1");
    return parsed_arg;
}

const FlagTuple = std.meta.Tuple(&[_]type{ []const u8, ?[]const u8 });

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

fn findArgByLongName(valid_args: []const Arg, long_name: []const u8) ?*const Arg {
    for (valid_args) |*valid_arg| {
        if (valid_arg.long_name) |valid_long_name| {
            if (mem.eql(u8, valid_long_name, long_name))
                return valid_arg;
        }
    }
    return null;
}

pub fn consumeArgValue(
    self: *Parser,
    arg: *const Arg,
    attached_value: ?[]const u8,
) InternalError!MatchedArg {
    if (arg.min_values) |min_values| {
        if (min_values == 0) {
            if (attached_value != null) {
                return InternalError.AttachedValueNotConsumed;
            } else if (arg.settings.allow_empty_value) {
                return MatchedArg.initWithSingleValue(arg.name, " ");
            }
        }
    }

    if (attached_value) |val| {
        return self.processValue(arg, val, true);
    } else {
        const value = self.tokenizer.nextNonFlagArg() orelse return Error.ArgValueNotProvided;
        return self.processValue(arg, value, false);
    }
}

pub fn processValue(
    self: *Parser,
    arg: *const Arg,
    value: []const u8,
    is_attached_value: bool,
) Error!MatchedArg {
    if (arg.values_delimiter) |delimiter| {
        var values_iter = mem.split(u8, value, delimiter);
        var values = std.ArrayList([]const u8).init(self.allocator);
        errdefer values.deinit();

        while (values_iter.next()) |val| {
            const _val = @as([]const u8, val);

            if ((_val.len == 0) and !(arg.settings.allow_empty_value))
                return Error.EmptyArgValueNotAllowed;

            if (!arg.verifyValueInAllowedValues(_val))
                return Error.ValueIsNotInAllowedValues;

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
                    return Error.EmptyArgValueNotAllowed;

                if (!arg.verifyValueInAllowedValues(_value))
                    return Error.ValueIsNotInAllowedValues;

                try values.append(_value);
            }
            return MatchedArg.initWithManyValues(arg.name, values);
        }
    }
}

pub fn parseSubCommand(
    self: *Parser,
    provided_subcmd: []const u8,
) Error!arg_matches.SubCommand {
    for (self.cmd.subcommands.items) |valid_subcmd| {
        if (mem.eql(u8, valid_subcmd.name, provided_subcmd)) {
            // zig fmt: off
            if (valid_subcmd.setting.takes_value
                or valid_subcmd.args.items.len >= 1
                or valid_subcmd.subcommands.items.len >= 1) {
                // zig fmt: on
                const subcmd_argv = self.tokenizer.restArg() orelse return Error.CommandArgumentNotProvided;
                var parser = Parser.init(self.allocator, subcmd_argv, &valid_subcmd);
                const subcmd_argmatches = try parser.parse();

                return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
            }
            return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);
        }
    }
    return Error.UnknownCommand;
}

const ShortFlag = struct {
    name: []const u8,
    value: ?[]const u8,
    cursor: usize,

    pub fn initFromToken(token: *Token) ShortFlag {
        const flag_tuple = flagTokenToFlagTuple(token);

        var self = .{
            .name = flag_tuple.@"0",
            .value = flag_tuple.@"1",
            .cursor = 0,
        };

        return self;
    }

    pub fn next(self: *ShortFlag) ?u8 {
        if (self.cursor >= self.name.len) return null;
        defer self.cursor += 1;

        return self.name[self.cursor];
    }

    pub fn getValue(self: *ShortFlag) ?[]const u8 {
        return (self.value);
    }

    pub fn getRemainTail(self: *ShortFlag) ?[]const u8 {
        if (self.cursor >= self.name.len) return null;
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
};
