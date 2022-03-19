const std = @import("std");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const testing = std.testing;

test "command parser" {
    const allocator = std.heap.page_allocator;

    var cmd = Command.new(allocator, "test");
    try cmd.flag(Flag.ArgOne("--gen-makefile"));
    try cmd.subCommand(Command.new(allocator, "help"));
    try cmd.subCommand(Command.new(allocator, "clean"));

    var compile_cmd = Command.new(allocator, "compile");
    try compile_cmd.flag(Flag.Option("--mode", &[_][]const u8{
        "debug",
        "release",
    }));

    compile_cmd.flagRequired(true);

    try cmd.subCommand(compile_cmd);

    const argv: []const [:0]const u8 = &.{
        "compile",
        "--mode",
    };

    var matches = try cmd.parse(argv);

    if (matches.subcommandMatches("build")) |build_cmd_matches| {
        try testing.expectEqualSlices(u8, "debug", build_cmd_matches.valueOf("--mode").?);
    }
}
