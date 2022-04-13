const std = @import("std");
const arg_matches = @import("arg_matches.zig");
const Command = @import("Command.zig");
const Arg = @import("Arg.zig");
const ArgvIterator = @import("ArgvIterator.zig");
const MatchedArg = @import("MatchedArg.zig");

const Allocator = std.mem.Allocator;
const ArgMatches = arg_matches.ArgMatches;

pub const Error = error{
    UnknownArg,
    UnknownCommand,
    MissingCommandArgument,
    MissingCommandSubCommand,
    IncompleteArgValues,
    ValueIsNotInAllowedValues,
} || Allocator.Error;

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
            if (!std.mem.startsWith(u8, arg.name, "--")) {
                var parsed_arg = try consumeArgValues(allocator, &arg, &argv_iter);
                try matches.putMatchedArg(parsed_arg);
            }
        }
    }

    while (argv_iter.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            if (cmd.args.items.len == 0)
                return Error.UnknownArg;

            const parsed_arg = try parseArg(allocator, cmd.args.items, arg, &argv_iter);
            try matches.putMatchedArg(parsed_arg);
        } else {
            if (cmd.subcommands.items.len == 0)
                return Error.UnknownCommand;

            const subcmd = try parseSubCommand(allocator, cmd.subcommands.items, arg, &argv_iter);
            try matches.setSubcommand(subcmd);
        }
    }

    if (cmd.setting.arg_required and matches.args.count() == 0) {
        return Error.MissingCommandArgument;
    }

    if (cmd.setting.subcommand_required and matches.subcommand == null) {
        return Error.MissingCommandSubCommand;
    }

    return matches;
}

pub fn parseArg(
    allocator: Allocator,
    valid_args: []const Arg,
    provided_arg: [:0]const u8,
    argv_iterator: *ArgvIterator,
) Error!MatchedArg {
    for (valid_args) |arg| {
        if (std.mem.eql(u8, arg.name, provided_arg)) {
            return consumeArgValues(allocator, &arg, argv_iterator);
        }
    }
    return Error.UnknownArg;
}

pub fn consumeArgValues(
    allocator: Allocator,
    arg: *const Arg,
    argv_iterator: *ArgvIterator,
) Error!MatchedArg {
    if (arg.min_values == 0)
        return MatchedArg.initWithoutValue(arg.name);

    if (arg.min_values == 1 and arg.max_values == 1) {
        var provided_value = argv_iterator.nextValue() orelse {
            if (arg.settings.all_values_required)
                return Error.IncompleteArgValues;

            return MatchedArg.initWithoutValue(arg.name);
        };

        if (!arg.verifyValueInAllowedValues(provided_value))
            return Error.ValueIsNotInAllowedValues;

        return MatchedArg.initWithSingleValue(arg.name, provided_value);
    }

    if (arg.min_values >= 1 and arg.max_values >= arg.min_values) {
        var index: usize = 1;
        var values = std.ArrayList([]const u8).init(allocator);
        errdefer values.deinit();

        while (index <= arg.max_values) : (index += 1) {
            var provided_value = argv_iterator.nextValue() orelse break;

            if (!arg.verifyValueInAllowedValues(provided_value))
                return Error.ValueIsNotInAllowedValues;
            try values.append(provided_value);
        }

        if (values.items.len < arg.max_values and arg.settings.all_values_required)
            return Error.IncompleteArgValues;

        return MatchedArg.initWithManyValues(arg.name, values);
    }
    return MatchedArg.initWithoutValue(arg.name);
}

pub fn parseSubCommand(
    allocator: Allocator,
    valid_subcmds: []const Command,
    provided_subcmd: [:0]const u8,
    argv_iterator: *ArgvIterator,
) Error!arg_matches.SubCommand {
    for (valid_subcmds) |valid_subcmd| {
        if (std.mem.eql(u8, valid_subcmd.name, provided_subcmd)) {
            // zig fmt: off
            if (valid_subcmd.setting.takes_value
                or valid_subcmd.args.items.len >= 1
                or valid_subcmd.subcommands.items.len >= 1) {
                // zig fmt: on
                const subcmd_argv = argv_iterator.rest() orelse return Error.MissingCommandArgument;
                const subcmd_argmatches = try parse(allocator, subcmd_argv, &valid_subcmd);

                return arg_matches.SubCommand.initWithArg(valid_subcmd.name, subcmd_argmatches);
            }
            return arg_matches.SubCommand.initWithoutArg(valid_subcmd.name);
        }
    }
    return Error.UnknownCommand;
}
