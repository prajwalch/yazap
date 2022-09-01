const std = @import("std");
const Command = @import("Command.zig");
const flag = @import("flag.zig");
const Arg = @import("Arg.zig");
const testing = std.testing;

const allocator = std.heap.page_allocator;

fn initAppArgs(alloc: std.mem.Allocator) !Command {
    var app = Command.new(alloc, "app");

    // app <ARG-ONE>
    try app.takesSingleValue("ARG-ONE");
    // app <ARG-MANY...>
    try app.takesNValues("ARG-MANY", 3);

    // app [-b, --bool-flag]
    try app.addArg(flag.boolean("bool-flag", 'b'));
    try app.addArg(flag.boolean("bool-flag2", 'c'));
    // var bool_flag = Arg.new("bool-flag");
    // bool_flag.shortName('b');
    // bool_flag.setLongNameSameAsName();
    // try app.addArg(bool_flag);

    // app [-1, --arg_one_flag <VALUE>]
    try app.addArg(flag.argOne("arg-one-flag", '1'));
    // var arg_one_flag = Arg.new("arg-one-flag");
    // arg_one_flag.shortName('1');
    // arg_one_flag.setLongNameSameAsName();
    // arg_one_flag.takesValue(true);
    // try app.addArg(arg_one_flag);

    // app [-3, --argn-flag <VALUE...>
    try app.addArg(flag.argN("argn-flag", '3', 3));
    // var argn_flag = Arg.new("argn-flag");
    // argn_flag.shortName('3');
    // argn_flag.setLongNameSameAsName();
    // argn_flag.maxValues(3);
    // argn_flag.valuesDelimiter(",");
    // try app.addArg(argn_flag);

    // app [-o, --option-flag <opt1 | opt2 | opt3>]
    try app.addArg(flag.option("option-flag", 'o', &[_][]const u8{
        "opt1",
        "opt2",
        "opt3",
    }));
    // var opt_flag = Arg.new("option-flag");
    // opt_flag.shortName('o');
    // opt_flag.setLongNameSameAsName();
    // opt_flag.allowedValues(&[_][]const u8{
    // "opt1",
    // "opt2",
    // "opt3",
    // });
    // try app.addArg(opt_flag);

    // app subcmd1
    try app.addSubcommand(Command.new(alloc, "subcmd1"));
    return app;
}

test "arg required error" {
    const argv: []const [:0]const u8 = &.{
        "--mode",
        "debug",
    };

    var app = try initAppArgs(allocator);
    app.argRequired(true);
    defer app.deinit();

    try testing.expectError(error.CommandArgumentNotProvided, app.parseFrom(argv));
}

test "subcommand required error" {
    const argv: []const [:0]const u8 = &.{
        "",
    };

    var app = try initAppArgs(allocator);
    app.subcommandRequired(true);
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
    defer matches.deinit();

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

    var cmd = Command.new(allocator, "appi");
    defer cmd.deinit();
    cmd.takesValue(true);

    var files = Arg.new("files");
    //files.takesValue(true);
    files.takesMultipleValues(true);

    try cmd.addArg(files);
    var args = try cmd.parseFrom(argv);
    defer args.deinit();

    if (args.valuesOf("files")) |f| {
        try testing.expect(f.len == 4);
    }
}
