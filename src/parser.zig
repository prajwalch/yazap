const std = @import("std");
const arg_matches = @import("arg_matches.zig");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const ArgvIterator = @import("ArgvIterator.zig");
const MatchedFlag = @import("MatchedFlag.zig");
const ArgMatches = arg_matches.ArgMatches;

pub const Error = error{
    UnknownFlag,
    UnknownCommand,
    MissingFlagArgument,
    MissingCommandArgument,
    MissingCommandFlags,
    ArgIsNotInAllowedSet,
} || std.mem.Allocator.Error;

pub fn parse(allocator: std.mem.Allocator, argv: []const [:0]const u8, cmd: *const Command) Error!ArgMatches {
    var argv_iter = ArgvIterator.init(argv);
    var matches = ArgMatches.init(allocator);
    errdefer matches.deinit();

    if (cmd.isSettingEnabled(.takes_value)) {
        const provided_value = argv_iter.next() orelse return Error.MissingCommandArgument;
        matches.setValue(provided_value.name);
    }

    while (argv_iter.next()) |arg| {
        if (arg.startsWithDoubleHyphen()) {
            if (cmd.flags) |flags| {
                const parsed_flag = try parseFlag(allocator, flags.items, &arg, &argv_iter);
                try matches.putFlag(parsed_flag);
            } else {
                return Error.UnknownFlag;
            }
        } else {
            if (cmd.subcommands) |subcmds| {
                const subcmd = try parseSubCommand(allocator, subcmds.items, &arg, &argv_iter);
                try matches.setSubcommand(subcmd);
            } else {
                return Error.UnknownCommand;
            }
        }
    }

    if (cmd.isSettingEnabled(.flag_required) and matches.flags.count() == 0) {
        return Error.MissingCommandFlags;
    }

    if (cmd.isSettingEnabled(.subcommand_required) and matches.subcommand == null) {
        return Error.MissingCommandArgument;
    }

    return matches;
}

pub fn parseFlag(
    allocator: std.mem.Allocator,
    valid_flags: []const Flag,
    provided_flag: *const ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) Error!MatchedFlag {
    for (valid_flags) |flag| {
        if (std.mem.eql(u8, flag.name, provided_flag.name)) {
            return consumeFlagArg(allocator, &flag, provided_flag, argv_iterator);
        }
    }
    return Error.UnknownFlag;
}

pub fn consumeFlagArg(
    allocator: std.mem.Allocator,
    flag: *const Flag,
    provided_flag: *const ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) Error!MatchedFlag {
    switch (flag.required_arg) {
        0 => return MatchedFlag.initWithoutArg(flag.name),
        1 => {
            const provided_arg = provided_flag.arg(argv_iterator) orelse return Error.MissingFlagArgument;

            if (!flag.verifyArgInAllowedSet(provided_arg)) {
                return Error.ArgIsNotInAllowedSet;
            }

            return MatchedFlag.initWithSingleArg(flag.name, provided_arg);
        },
        else => |num_required_arg| {
            var args = std.ArrayList([]const u8).init(allocator);
            var index: usize = 1;

            while (index <= num_required_arg) : (index += 1) {
                const arg = provided_flag.arg(argv_iterator) orelse return Error.MissingFlagArgument;

                if (!flag.verifyArgInAllowedSet(arg)) {
                    return Error.ArgIsNotInAllowedSet;
                }

                try args.append(arg);
            }

            return MatchedFlag.initWithManyArg(flag.name, args);
        },
    }
}

pub fn parseSubCommand(
    allocator: std.mem.Allocator,
    valid_subcmds: []const Command,
    provided_subcmd: *const ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) Error!arg_matches.SubCommand {
    for (valid_subcmds) |valid_subcmd| {
        if (std.mem.eql(u8, valid_subcmd.name, provided_subcmd.name)) {
            if (!valid_subcmd.takesArg())
                return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);

            const subcmd_argv = argv_iterator.rest() orelse return Error.MissingCommandArgument;
            const subcmd_argmatches = try parse(allocator, subcmd_argv, &valid_subcmd);

            return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
        }
    }
    return Error.UnknownCommand;
}
