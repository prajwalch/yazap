const std = @import("std");
const lib = @import("lib.zig");

const testing = std.testing;
const allocator = testing.allocator;
const flag = lib.flag;
const App = lib.App;
const Arg = lib.Arg;

test "command that takes single value" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.new("PATH", null));
    app.rootCommand().applySetting(.takes_value);

    const args = try app.parseFrom(&.{"test.txt"});
    try testing.expectEqualStrings("test.txt", args.valueOf("PATH").?);

    app.deinit();
}

test "command that takes many values" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    var paths = Arg.new("PATHS", null);
    paths.applySetting(.takes_multiple_values);
    paths.applySetting(.takes_value);

    try app.rootCommand().addArg(paths);
    app.rootCommand().applySetting(.takes_value);

    const args = try app.parseFrom(&.{ "a", "b", "c" });
    try testing.expectEqualSlices([]const u8, &.{ "a", "b", "c" }, args.valuesOf("PATHS").?);

    app.deinit();
}

test "command that takes many values using delimiter" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    var paths = Arg.new("PATHS", null);
    paths.applySetting(.takes_multiple_values);
    paths.setValuesDelimiter(":");

    try app.rootCommand().addArg(paths);
    app.rootCommand().applySetting(.takes_value);

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

    try app.rootCommand().addArg(Arg.new("PATH", null));
    app.rootCommand().applySetting(.takes_value);
    app.rootCommand().applySetting(.arg_required);
    try testing.expectError(error.CommandArgumentNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "command requires subcommand" {
    var app = App.init(allocator, "git", null);
    errdefer app.deinit();

    try app.rootCommand().addSubcommand(app.createCommand("init", null));
    app.rootCommand().applySetting(.subcommand_required);
    try testing.expectError(error.CommandSubcommandNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "Option that does not takes value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var recursive = Arg.new("version", null);
    recursive.setShortName('v');

    try app.rootCommand().addArg(recursive);
    try testing.expectError(error.UnneededAttachedValue, app.parseFrom(&.{"-v=13"}));

    app.deinit();
}

test "Option that takes single value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var browser = Arg.new("output", null);
    browser.setShortName('o');
    browser.applySetting(.takes_value);

    try app.rootCommand().addArg(browser);
    try testing.expectError(error.ArgValueNotProvided, app.parseFrom(&.{"-o"}));

    app.deinit();
}

test "Option that takes many/multiple values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.new("sources", null);
    srcs.setShortName('s');
    srcs.setValuesDelimiter(":");
    srcs.applySetting(.takes_value);
    srcs.applySetting(.takes_multiple_values);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);
    const args = try app.parseFrom(&.{ "-s", "f1", "f2", "f3", "f4", "f5" });

    try testing.expectEqual(@as(usize, 5), args.valuesOf("sources").?.len);

    app.deinit();
}

test "Option with min values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.new("sources", null);
    srcs.setShortName('s');
    srcs.setMinValues(2);
    srcs.setValuesDelimiter(":");

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooFewArgValue, app.parseFrom(&.{"-s=f1"}));

    app.deinit();
}

test "Option with max values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.new("sources", null);
    srcs.setShortName('s');
    srcs.setMinValues(2);
    srcs.setMaxValues(5);
    srcs.setValuesDelimiter(":");

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooManyArgValue, app.parseFrom(
        &.{"-s=f1:f2:f3:f4:f5:f6"},
    ));

    app.deinit();
}

test "Option with allowed values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var stdd = Arg.new("std", null);
    stdd.setLongName("std");
    stdd.setAllowedValues(&.{ "c99", "c11", "c17" });

    try app.rootCommand().addArg(stdd);
    try testing.expectError(error.ProvidedValueIsNotValidOption, app.parseFrom(&.{"--std=c100"}));

    app.deinit();
}
