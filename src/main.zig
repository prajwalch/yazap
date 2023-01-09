const std = @import("std");
const Command = @import("Command.zig");
const flag = @import("flag.zig");
const Arg = @import("Arg.zig");
const App = @import("App.zig");
const testing = std.testing;

const allocator = testing.allocator;

fn initAppArgs(alloc: std.mem.Allocator) !App {
    var app = App.init(alloc, "app", "Test app description");
    errdefer app.deinit();

    var root_cmd = app.rootCommand();

    try root_cmd.takesSingleValue("ARG-ONE");
    try root_cmd.takesNValues("ARG-MANY", 3);

    try root_cmd.addArgs(&[_]Arg{
        flag.boolean("bool-flag", 'b', null),
        flag.boolean("bool-flag2", 'c', null),
        flag.argOne("arg-one-flag", '1', null),
        flag.argN("argn-flag", '3', 3, null),
        flag.option("option-flag", 'o', &[_][]const u8{
            "opt1",
            "opt2",
            "opt3",
        }, null),
    });

    try root_cmd.addSubcommand(app.createCommand("subcmd1", "First sub command"));
    return app;
}

test "arg required error" {
    const argv: []const [:0]const u8 = &.{
        "--mode",
        "debug",
    };

    var app = try initAppArgs(allocator);
    app.rootCommand().applySetting(.arg_required);
    defer app.deinit();

    try testing.expectError(error.CommandArgumentNotProvided, app.parseFrom(argv));
}

test "subcommand required error" {
    const argv: []const [:0]const u8 = &.{
        "",
    };

    var app = try initAppArgs(allocator);
    app.rootCommand().applySetting(.subcommand_required);
    defer app.deinit();

    try testing.expectError(error.CommandSubcommandNotProvided, app.parseFrom(argv));
}

test "command that takes value" {
    const argv: []const [:0]const u8 = &.{
        "argone",
        "argmany1",
        "argmany2",
        "argmany3",
    };

    var app = try initAppArgs(allocator);
    defer app.deinit();

    var matches = try app.parseFrom(argv);
    try testing.expectEqualStrings("argone", matches.valueOf("ARG-ONE").?);

    const many_values = matches.valuesOf("ARG-MANY").?;
    try testing.expectEqualStrings("argmany1", many_values[0]);
    try testing.expectEqualStrings("argmany2", many_values[1]);
    try testing.expectEqualStrings("argmany3", many_values[2]);
}

test "flags" {
    const argv: []const [:0]const u8 = &.{
        "-bc",
        "-1one",
        "--argn-flag=val1,val2,val3",
        "--option-flag",
        "opt2",
    };

    var app = try initAppArgs(allocator);
    defer app.deinit();

    var matches = try app.parseFrom(argv);
    try testing.expect(matches.isPresent("bool-flag") == true);
    try testing.expect(matches.isPresent("bool-flag2") == true);
    try testing.expectEqualStrings("one", matches.valueOf("arg-one-flag").?);
    //try testing.expect(2 == matches.valuesOf("arg-one-flag").?.len);

    const argn_values = matches.valuesOf("argn-flag").?;
    try testing.expectEqualStrings("val1", argn_values[0]);
    try testing.expectEqualStrings("val2", argn_values[1]);
    try testing.expectEqualStrings("val3", argn_values[2]);
    try testing.expectEqualStrings("opt2", matches.valueOf("option-flag").?);
}

test "arg.takes_multiple_values" {
    const argv: []const [:0]const u8 = &.{
        "file1.zig",
        "file1.zig",
        "file1.zig",
        "file1.zig",
    };

    var app = try initAppArgs(allocator);
    defer app.deinit();
    app.rootCommand().applySetting(.takes_value);

    var files = Arg.new("files");
    files.applySetting(.takes_multiple_values);

    try app.rootCommand().addArg(files);
    var args = try app.parseFrom(argv);

    if (args.valuesOf("files")) |f| {
        try testing.expect(f.len == 4);
    }
}

test "using displayHelp and displaySubcommandHelp help api" {
    const argv: []const [:0]const u8 = &.{"subcmd"};

    var app = try initAppArgs(allocator);
    defer app.deinit();
    app.rootCommand().removeSetting(.takes_value);

    var subcmd = app.createCommand("subcmd", null);
    try subcmd.addArg(flag.boolean("bool", null, null));
    try app.rootCommand().addSubcommand(subcmd);

    var args = try app.parseFrom(argv);

    if (args.subcommandContext("subcmd")) |sargs| {
        if (!sargs.hasArgs()) {
            try app.displaySubcommandHelp();
        }
    }
}

test "auto help generation" {
    const argv: []const [:0]const u8 = &.{"-h"};

    var app = try initAppArgs(allocator);
    defer app.deinit();

    _ = try app.parseFrom(argv);
}
