const Parser = @This();

const std = @import("std");
const arg_matches = @import("arg_matches.zig");
const Command = @import("Command.zig");
const Arg = @import("Arg.zig");
const ArgvIterator = @import("ArgvIterator.zig");
const MatchedArg = @import("MatchedArg.zig");

const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArgMatches = arg_matches.ArgMatches;

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
argv_iter: ArgvIterator,
cmd: *const Command,

pub fn init(
    allocator: Allocator,
    argv: []const [:0]const u8,
    command: *const Command,
) Parser {
    return Parser{
        .allocator = allocator,
        .argv_iter = ArgvIterator.init(argv),
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

    while (self.argv_iter.next()) |*raw_arg| {
        if (raw_arg.isShort() or raw_arg.isLong()) {
            if (self.cmd.args.items.len == 0)
                return Error.UnknownArg;

            try self.parseArg(raw_arg, &matches);
        } else {
            if (self.cmd.subcommands.items.len == 0)
                return Error.UnknownCommand;

            const subcmd = try self.parseSubCommand(raw_arg.name);
            try matches.setSubcommand(subcmd);
        }
    }

    if (self.cmd.setting.subcommand_required and matches.subcommand == null) {
        return Error.MissingCommandSubCommand;
    }

    return matches;
}

pub fn parseArg(self: *Parser, raw_arg: *ArgvIterator.RawArg, matches: *ArgMatches) Error!void {
    if (raw_arg.isShort()) {
        if (raw_arg.toShort()) |*short_arg| {
            const parsed_args = try self.parseShortArg(short_arg);

            for (parsed_args) |parsed_arg| {
                try matches.putMatchedArg(parsed_arg);
            }
        }
    } else if (raw_arg.isLong()) {
        if (raw_arg.toLong()) |*long_arg| {
            const parsed_arg = try self.parseLongArg(long_arg);
            try matches.putMatchedArg(parsed_arg);
        }
    }
}

fn parseShortArg(self: *Parser, short_args: *ArgvIterator.ShortFlags) Error![]const MatchedArg {
    var parsed_args = std.ArrayList(MatchedArg).init(self.allocator);
    errdefer parsed_args.deinit();

    while (short_args.nextFlag()) |short_flag| {
        if (findArgByShortName(self.cmd.args.items, short_flag)) |arg| {
            if (!arg.settings.takes_value) {
                if (short_args.fixed_value) |val| {
                    if (val.len >= 1) {
                        return Error.UnneededAttachedValue;
                    } else {
                        return Error.UnneededEmptyAttachedValue;
                    }
                }
                try parsed_args.append(MatchedArg.initWithoutValue(arg.name));
                continue;
            }

            const value = short_args.nextValue();
            const parsed_arg = self.consumeArgValue(arg, value) catch |err| switch (err) {
                InternalError.AttachedValueNotConsumed => {
                    // If attached value is not consumed, we may have more flags to parse
                    short_args.rollbackValue();
                    try parsed_args.append(MatchedArg.initWithoutValue(arg.name));
                    continue;
                },
                else => |e| return e,
            };
            try parsed_args.append(parsed_arg);
        } else {
            return Error.UnknownFlag;
        }
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

fn parseLongArg(self: *Parser, long_arg: *ArgvIterator.LongFlag) Error!MatchedArg {
    if (findArgByLongName(self.cmd.args.items, long_arg.name)) |arg| {
        if (!arg.settings.takes_value) {
            if (long_arg.value != null) {
                return Error.UnneededAttachedValue;
            } else {
                return MatchedArg.initWithoutValue(arg.name);
            }
        }

        const parsed_arg = self.consumeArgValue(arg, long_arg.value) catch |err| switch (err) {
            InternalError.AttachedValueNotConsumed => {
                return MatchedArg.initWithoutValue(arg.name);
            },
            else => |e| return e,
        };
        return parsed_arg;
    } else {
        return Error.UnknownFlag;
    }
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
        const value = self.argv_iter.nextValue() orelse return Error.ArgValueNotProvided;
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

            // consume each value using ArgvIterator
            while (index <= num_remaining_values) : (index += 1) {
                const _value = self.argv_iter.nextValue() orelse break;

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
                const subcmd_argv = self.argv_iter.rest() orelse return Error.CommandArgumentNotProvided;
                var parser = Parser.init(self.allocator, subcmd_argv, &valid_subcmd);
                const subcmd_argmatches = try parser.parse();

                return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
            }
            return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);
        }
    }
    return Error.UnknownCommand;
}
