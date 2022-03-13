const std = @import("std");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const ArgMatches = @import("ArgMatches.zig");
const ArgvIterator = @import("ArgvIterator.zig");

fn parse(argv: []const [:0]const u8, cmd: *Command) !ArgMatches {
    var argv_iter = ArgvIterator.init(argv);

    while (argv_iter.next()) |arg| {
        if (arg.startsWithDoubleHyphen()) {
            if (cmd.flags) |flags| {
                const parsed_flag = try parseFlag(flags, &arg, &argv_iter);
                try arg_matches.putFlag(parsed_flag);
            } else {
                return error.UnknownFlag;
            }
        } else {
            if (cmd.subcommands) |subcmds| {
                const subcmd = try parseSubCommand(subcmds, &arg, &argv_iter);
                try arg_matches.putSubCommand(subcmd);
            } else {
                return error.UnknownCommand;
            }
        }
    }
}

pub fn parseFlag(
    valid_flags: []const Flag,
    provided_flag: *ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) !MatchedFlag {
    for (valid_flags) |flag| {
        if (std.mem.eql(u8, flag.name, provided_flag.name)) {
            return consumeFlagArg(&flag, provided_flag, argv_iterator);
        }
    }
}

pub fn consumeFlagArg(flag: *Flag, provided_flag: *ArgvIterator.Value, argv_iterator: *ArgvIterator) !MatchedFlag {
    switch (flag.required_arg) {
        0 => return MatchedFlag.initWithoutArg(flag.name),
        1 => {
            const provided_arg = provided_flag.arg(argv_iterator) orelse return error.MissingFlagArgument;

            if (!flag.verifyArgInAllowedSet(provided_arg)) {
                return error.ArgIsNotInAllowedSet;
            }

            return MatchedFlag.initWithArg(flag.name, provided_arg);
        },
    }
}

pub fn parseSubCommand(
    valid_subcmds: []const Command,
    provided_subcmd: *ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) !ArgMatches.SubCommand {
    for (valid_subcmds) |valid_subcmd| {
        if (std.mem.eql(u8, valid_subcmd.name, provided_subcmd.name)) {
            if (!valid_cmd.takes_arg)
                return ArgMatches.SubCommand.initWithoutArg(valid_subcmd.name);

            const subcmd_argv = argv_iterator.rest() orelse return error.MissingCommandArgument;
            const subcmd_argmatches = try parse(subcmd_argv, &valid_subcmd);

            return ArgMatches.SubCommand.initWithArgMatches(valid_subcmd.name, subcmd_argmatches);
        }
    }
}
