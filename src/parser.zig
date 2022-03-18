const std = @import("std");
const arg_matches = @import("arg_matches.zig");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const ArgvIterator = @import("ArgvIterator.zig");
const MatchedFlag = @import("MatchedFlag.zig");
const ArgMatches = arg_matches.ArgMatches;

fn parse(argv: []const [:0]const u8, cmd: *Command) !ArgMatches {
    var argv_iter = ArgvIterator.init(argv);
    var matches = ArgMatches.init(allocator);
    errdefer matches.deinit();

    while (argv_iter.next()) |arg| {
        if (arg.startsWithDoubleHyphen()) {
            if (cmd.flags) |flags| {
                const parsed_flag = try parseFlag(flags.items, &arg, &argv_iter);
                try matches.putFlag(parsed_flag);
            } else {
                return error.UnknownFlag;
            }
        } else {
            if (cmd.subcommands) |subcmds| {
                const subcmd = try parseSubCommand(subcmds.items, &arg, &argv_iter);
                try matches.setSubcommand(subcmd);
            } else {
                return error.UnknownCommand;
            }
        }
    }
    return matches;
}

pub fn parseFlag(
    valid_flags: []const Flag,
    provided_flag: *const ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) !MatchedFlag {
    for (valid_flags) |flag| {
        if (std.mem.eql(u8, flag.name, provided_flag.name)) {
            return consumeFlagArg(&flag, provided_flag, argv_iterator);
        }
    }
    return error.UnknownFlag;
}

pub fn consumeFlagArg(flag: *const Flag, provided_flag: *const ArgvIterator.Value, argv_iterator: *ArgvIterator) !MatchedFlag {
    switch (flag.required_arg) {
        0 => return MatchedFlag.initWithoutArg(flag.name),
        1 => {
            const provided_arg = provided_flag.arg(argv_iterator) orelse return error.MissingFlagArgument;

            if (!flag.verifyArgInAllowedSet(provided_arg)) {
                return error.ArgIsNotInAllowedSet;
            }

            return MatchedFlag.initWithArg(flag.name, provided_arg);
        },
        else => @panic("Flag reuqires more arg, yet to handle"),
    }
}

pub fn parseSubCommand(
    valid_subcmds: []const Command,
    provided_subcmd: *const ArgvIterator.Value,
    argv_iterator: *ArgvIterator,
) !arg_matches.SubCommand {
    for (valid_subcmds) |valid_subcmd| {
        if (std.mem.eql(u8, valid_subcmd.name, provided_subcmd.name)) {
            if (!valid_subcmd.takesArg())
                return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);

            const subcmd_argv = argv_iterator.rest() orelse return error.MissingCommandArgument;
            const subcmd_argmatches = try parse(subcmd_argv, &valid_subcmd);

            return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
        }
    }
    return error.UnknownCommand;
}
