const std = @import("std");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const testing = std.testing;

const allocator = std.heap.page_allocator;

fn initFakeCliArgs(alloc: std.mem.Allocator) !Command {
    var root_cmd = Command.new(alloc, "zig-arg");

    try root_cmd.flag(Flag.Bool("--version"));
    try root_cmd.flag(Flag.ArgOne("--compile-only"));
    try root_cmd.subCommand(Command.new(alloc, "help"));

    var compile_cmd = Command.new(alloc, "compile");
    try compile_cmd.flag(Flag.Option("--mode", &[_][]const u8{
        "release",
        "debug",
    }));

    try root_cmd.subCommand(compile_cmd);
    return root_cmd;
}

test "flag required error" {
    const argv: []const [:0]const u8 = &.{
        "compile",
        "--mode",
        "debug",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    root_cmd.flagRequired(true);

    try testing.expectError(error.MissingCommandFlags, root_cmd.parse(argv));
}

test "subcommand required error" {
    const argv: []const [:0]const u8 = &.{
        "--version",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    root_cmd.subcommandRequired(true);

    try testing.expectError(error.MissingCommandArgument, root_cmd.parse(argv));
}

test "full parsing" {
    const argv: []const [:0]const u8 = &.{
        "compile",
        "--mode",
        "debug",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    defer root_cmd.deinit();

    root_cmd.subcommandRequired(true);
    var matches = try root_cmd.parse(argv);

    try testing.expectEqual(false, matches.isPresent("--version"));

    if (matches.subcommandMatches("compile")) |compile_cmd_matches| {
        try testing.expectEqual(true, compile_cmd_matches.isPresent("--mode"));
        try testing.expectEqualStrings("debug", compile_cmd_matches.valueOf("--mode").?);
    }
}
