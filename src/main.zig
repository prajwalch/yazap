const std = @import("std");
const Command = @import("Command.zig");
const Flag = @import("Flag.zig");
const testing = std.testing;

const allocator = std.heap.page_allocator;

fn initFakeCliArgs(alloc: std.mem.Allocator) !Command {
    var root_cmd = Command.new(alloc, "zig-arg");

    try root_cmd.addArg(Flag.boolean("--version"));
    try root_cmd.addArg(Flag.argOne("--compile-only"));
    try root_cmd.addArg(Flag.argN("--exclude-dir", 3));
    try root_cmd.addSubcommand(Command.new(alloc, "help"));

    var compile_cmd = Command.new(alloc, "compile");
    try compile_cmd.addArg(Flag.option("--mode", &[_][]const u8{
        "release",
        "debug",
    }));

    try root_cmd.addSubcommand(compile_cmd);

    var init_cmd = Command.new(alloc, "init");
    try init_cmd.takesSingleValue("PROJECT_NAME");

    try root_cmd.addSubcommand(init_cmd);
    return root_cmd;
}

test "arg required error" {
    const argv: []const [:0]const u8 = &.{
        "compile",
        "--mode",
        "debug",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    root_cmd.argRequired(true);
    defer root_cmd.deinit();

    try testing.expectError(error.MissingCommandArgument, root_cmd.parse(argv));
}

test "subcommand required error" {
    const argv: []const [:0]const u8 = &.{
        "--version",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    root_cmd.subcommandRequired(true);
    defer root_cmd.deinit();

    try testing.expectError(error.MissingCommandSubCommand, root_cmd.parse(argv));
}

test "command that takes value" {
    const argv: []const [:0]const u8 = &.{
        "init",
        "test_project",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    defer root_cmd.deinit();

    var matches = try root_cmd.parse(argv);
    try testing.expectEqualStrings("test_project", matches.valueOf("PROJECT_NAME").?);
}

test "full parsing" {
    const argv: []const [:0]const u8 = &.{
        "--exclude-dir",
        "dir1",
        "dir2",
        "dir3",
        "compile",
        "--mode",
        "debug",
    };

    var root_cmd = try initFakeCliArgs(allocator);
    defer root_cmd.deinit();

    root_cmd.subcommandRequired(true);
    var matches = try root_cmd.parse(argv);

    try testing.expectEqual(false, matches.isPresent("--version"));
    try testing.expectEqual(true, matches.isPresent("exclude-dir"));

    if (matches.valuesOf("exclude-dir")) |dirs_name| {
        try testing.expectEqualStrings("dir1", dirs_name[0]);
        try testing.expectEqualStrings("dir2", dirs_name[1]);
        try testing.expectEqualStrings("dir3", dirs_name[2]);
    }

    if (matches.subcommandMatches("compile")) |compile_cmd_matches| {
        try testing.expectEqual(true, compile_cmd_matches.isPresent("mode"));
        try testing.expectEqualStrings("debug", compile_cmd_matches.valueOf("mode").?);
    }
}
