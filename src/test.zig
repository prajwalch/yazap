const std = @import("std");
const lib = @import("lib.zig");

const testing = std.testing;
const allocator = testing.allocator;
const App = lib.App;
const Arg = lib.Arg;

test "command that takes single value" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.init("PATH", null));
    app.rootCommand().addProperty(.takes_positional_arg);

    const args = try app.parseFrom(&.{"test.txt"});
    try testing.expectEqualStrings("test.txt", args.valueOf("PATH").?);

    app.deinit();
}

test "command that takes many values" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    var paths = Arg.init("PATHS", null);
    paths.addProperty(.takes_multiple_values);
    paths.addProperty(.takes_value);

    try app.rootCommand().addArg(paths);
    app.rootCommand().addProperty(.takes_positional_arg);

    const args = try app.parseFrom(&.{ "a", "b", "c" });
    try testing.expectEqualSlices([]const u8, &.{ "a", "b", "c" }, args.valuesOf("PATHS").?);

    app.deinit();
}

test "command that takes many values using delimiter" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    var paths = Arg.init("PATHS", null);
    paths.addProperty(.takes_multiple_values);
    paths.setValuesDelimiter(":");

    try app.rootCommand().addArg(paths);
    app.rootCommand().addProperty(.takes_positional_arg);

    const args = try app.parseFrom(&.{"a:b:c"});

    // This gives weird error like:
    // index 0 incorrect. expected { 97 }, found { 97 }
    //try testing.expectEqualSlices([]const u8, &.{ "a", "b", "c" }, args.valuesOf("PATHS").?);

    const given_paths = args.valuesOf("PATHS");
    try testing.expectEqual(true, given_paths != null);
    try testing.expectEqual(@as(usize, 3), given_paths.?.len);
    try testing.expectEqualStrings("a", given_paths.?[0]);
    try testing.expectEqualStrings("b", given_paths.?[1]);
    try testing.expectEqualStrings("c", given_paths.?[2]);

    app.deinit();
}

test "command that takes required value" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.init("PATH", null));
    app.rootCommand().addProperty(.takes_positional_arg);
    app.rootCommand().addProperty(.positional_arg_required);
    try testing.expectError(error.CommandArgumentNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "command requires subcommand" {
    var app = App.init(allocator, "git", null);
    errdefer app.deinit();

    try app.rootCommand().addSubcommand(app.createCommand("init", null));
    app.rootCommand().addProperty(.subcommand_required);
    try testing.expectError(error.CommandSubcommandNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "Option that does not takes value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var recursive = Arg.init("version", null);
    recursive.setShortName('v');

    try app.rootCommand().addArg(recursive);
    try testing.expectError(error.UnneededAttachedValue, app.parseFrom(&.{"-v=13"}));

    app.deinit();
}

test "Option that takes single value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var browser = Arg.init("output", null);
    browser.setShortName('o');
    browser.addProperty(.takes_value);

    try app.rootCommand().addArg(browser);
    try testing.expectError(error.ArgValueNotProvided, app.parseFrom(&.{"-o"}));

    app.deinit();
}

test "Option that takes many/multiple values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.init("sources", null);
    srcs.setShortName('s');
    srcs.setValuesDelimiter(":");
    srcs.addProperty(.takes_value);
    srcs.addProperty(.takes_multiple_values);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);
    const args = try app.parseFrom(&.{ "-s", "f1", "f2", "f3", "f4", "f5" });

    try testing.expectEqual(@as(usize, 5), args.valuesOf("sources").?.len);

    app.deinit();
}

test "Option with min values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.init("sources", null);
    srcs.setShortName('s');
    srcs.setMinValues(2);
    srcs.setValuesDelimiter(":");
    srcs.addProperty(.takes_value);

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooFewArgValue, app.parseFrom(&.{"-s=f1"}));

    app.deinit();
}

test "Option with max values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.init("sources", null);
    srcs.setShortName('s');
    srcs.setMinValues(2);
    srcs.setMaxValues(5);
    srcs.setValuesDelimiter(":");
    srcs.addProperty(.takes_value);

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooManyArgValue, app.parseFrom(
        &.{"-s=f1:f2:f3:f4:f5:f6"},
    ));

    app.deinit();
}

test "Option with allowed values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var stdd = Arg.init("std", null);
    stdd.setLongName("std");
    stdd.setValidValues(&.{ "c99", "c11", "c17" });
    stdd.addProperty(.takes_value);

    try app.rootCommand().addArg(stdd);
    try testing.expectError(error.ProvidedValueIsNotValidOption, app.parseFrom(&.{"--std=c100"}));

    app.deinit();
}

test "passing positional argument before options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().takesSingleValue("PATH");
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));
    app.rootCommand().addProperty(.positional_arg_required);

    const args = try app.parseFrom(&.{ ".", "-a" });
    try testing.expectEqualStrings(".", args.valueOf("PATH").?);
    try testing.expectEqual(true, args.isPresent("all"));

    app.deinit();
}

test "passing positional argument after options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().takesSingleValue("PATH");
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));

    const args = try app.parseFrom(&.{ "-a", "." });
    try testing.expectEqualStrings(".", args.valueOf("PATH").?);
    try testing.expectEqual(true, args.isPresent("all"));

    app.deinit();
}

test "passing positional argument before and after options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().takesSingleValue("PATH");
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));
    try app.rootCommand().addArg(Arg.booleanOption("one-line", '1', null));

    const args = try app.parseFrom(&.{ "-1", ".", "-a" });
    try testing.expectEqualStrings(".", args.valueOf("PATH").?);
    try testing.expectEqual(true, args.isPresent("one-line"));
    try testing.expectEqual(true, args.isPresent("all"));

    app.deinit();
}
