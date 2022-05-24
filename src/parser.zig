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

pub fn parse(
    allocator: Allocator,
    argv: []const [:0]const u8,
    cmd: *const Command,
) Error!ArgMatches {
    var argv_iter = ArgvIterator.init(argv);
    var matches = ArgMatches.init(allocator);
    errdefer matches.deinit();

    if (cmd.setting.takes_value) {
        for (cmd.args.items) |arg| {
            if ((arg.short_name == null) and (arg.long_name == null)) {
                var parsed_arg = consumeArgValue(allocator, &arg, null, &argv_iter) catch |err| switch (err) {
                    InternalError.AttachedValueNotConsumed => unreachable,
                    InternalError.ArgValueNotProvided => break,
                    else => |e| return e,
                };
                try matches.putMatchedArg(parsed_arg);
            }
        }

        if (cmd.setting.arg_required and (matches.args.count() == 0)) {
            return Error.CommandArgumentNotProvided;
        }
    }

    while (argv_iter.next()) |*raw_arg| {
        if (raw_arg.isShort() or raw_arg.isLong()) {
            if (cmd.args.items.len == 0)
                return Error.UnknownArg;

            try parseArg(allocator, cmd.args.items, raw_arg, &argv_iter, &matches);
        } else {
            if (cmd.subcommands.items.len == 0)
                return Error.UnknownCommand;

            const subcmd = try parseSubCommand(allocator, cmd.subcommands.items, raw_arg.name, &argv_iter);
            try matches.setSubcommand(subcmd);
        }
    }

    if (cmd.setting.subcommand_required and matches.subcommand == null) {
        return Error.MissingCommandSubCommand;
    }

    return matches;
}

pub fn parseArg(
    allocator: Allocator,
    valid_args: []const Arg,
    raw_arg: *ArgvIterator.RawArg,
    argv_iter: *ArgvIterator,
    matches: *ArgMatches,
) Error!void {
    if (raw_arg.isShort()) {
        if (raw_arg.toShort()) |*short_arg| {
            const parsed_args = try parseShortArg(allocator, valid_args, short_arg, argv_iter);

            for (parsed_args) |parsed_arg| {
                try matches.putMatchedArg(parsed_arg);
            }
        }
    } else if (raw_arg.isLong()) {
        if (raw_arg.toLong()) |*long_arg| {
            const parsed_arg = try parseLongArg(allocator, valid_args, long_arg, argv_iter);
            try matches.putMatchedArg(parsed_arg);
        }
    }
}

fn parseShortArg(
    allocator: Allocator,
    valid_args: []const Arg,
    short_args: *ArgvIterator.ShortFlags,
    argv_iter: *ArgvIterator,
) Error![]const MatchedArg {
    var parsed_args = std.ArrayList(MatchedArg).init(allocator);
    errdefer parsed_args.deinit();

    while (short_args.nextFlag()) |short_flag| {
        if (findArgByShortName(valid_args, short_flag)) |arg| {
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
            const parsed_arg = consumeArgValue(allocator, arg, value, argv_iter) catch |err| switch (err) {
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

fn parseLongArg(
    allocator: Allocator,
    valid_args: []const Arg,
    long_arg: *ArgvIterator.LongFlag,
    argv_iter: *ArgvIterator,
) Error!MatchedArg {
    if (findArgByLongName(valid_args, long_arg.name)) |arg| {
        if (!arg.settings.takes_value) {
            if (long_arg.value != null) {
                return Error.UnneededAttachedValue;
            } else {
                return MatchedArg.initWithoutValue(arg.name);
            }
        }

        const parsed_arg = consumeArgValue(allocator, arg, long_arg.value, argv_iter) catch |err| switch (err) {
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
    allocator: Allocator,
    arg: *const Arg,
    attached_value: ?[]const u8,
    argv_iter: *ArgvIterator,
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
        return processValue(allocator, arg, val, true, null);
    } else {
        const value = argv_iter.nextValue() orelse return Error.ArgValueNotProvided;
        return processValue(allocator, arg, value, false, argv_iter);
    }
}

pub fn processValue(
    allocator: Allocator,
    arg: *const Arg,
    value: []const u8,
    is_attached_value: bool,
    argv_iter: ?*ArgvIterator,
) Error!MatchedArg {
    if (arg.values_delimiter) |delimiter| {
        var values_iter = mem.split(u8, value, delimiter);
        var values = std.ArrayList([]const u8).init(allocator);
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
            var values = std.ArrayList([]const u8).init(allocator);
            errdefer values.deinit();

            try values.append(value);

            // consume each value using ArgvIterator
            while (index <= num_remaining_values) : (index += 1) {
                const _value = argv_iter.?.nextValue() orelse break;

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
    allocator: Allocator,
    valid_subcmds: []const Command,
    provided_subcmd: []const u8,
    argv_iterator: *ArgvIterator,
) Error!arg_matches.SubCommand {
    for (valid_subcmds) |valid_subcmd| {
        if (mem.eql(u8, valid_subcmd.name, provided_subcmd)) {
            // zig fmt: off
            if (valid_subcmd.setting.takes_value
                or valid_subcmd.args.items.len >= 1
                or valid_subcmd.subcommands.items.len >= 1) {
                // zig fmt: on
                const subcmd_argv = argv_iterator.rest() orelse return Error.CommandArgumentNotProvided;
                const subcmd_argmatches = try parse(allocator, subcmd_argv, &valid_subcmd);

                return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
            }
            return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);
        }
    }
    return Error.UnknownCommand;
}
