const std = @import("std");
const lib = @import("lib.zig");

const testing = std.testing;
const allocator = testing.allocator;
const App = lib.App;
const Arg = lib.Arg;

test "positional arguments with auto index" {
    var app = App.init(allocator, "app", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("ONE", null, null));
    try app.rootCommand().addArg(Arg.positional("TWO", null, null));
    try app.rootCommand().addArg(Arg.positional("THREE", null, null));

    const matches = try app.parseFrom(&.{ "val1", "val2", "val3" });
    try testing.expectEqualStrings("val1", matches.getSingleValue("ONE").?);
    try testing.expectEqualStrings("val2", matches.getSingleValue("TWO").?);
    try testing.expectEqualStrings("val3", matches.getSingleValue("THREE").?);

    app.deinit();
}

test "positional arguments with manual index" {
    var app = App.init(allocator, "app", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("ONE", null, 1));
    try app.rootCommand().addArg(Arg.positional("THREE", null, 3));
    try app.rootCommand().addArg(Arg.positional("TWO", null, 2));

    const matches = try app.parseFrom(&.{ "val1", "val2", "val3" });
    try testing.expectEqualStrings("val1", matches.getSingleValue("ONE").?);
    try testing.expectEqualStrings("val2", matches.getSingleValue("TWO").?);
    try testing.expectEqualStrings("val3", matches.getSingleValue("THREE").?);

    app.deinit();
}

test "positional arguments with same index" {
    var app = App.init(allocator, "app", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("ONE", null, 1));
    try testing.expectError(
        error.DuplicatePositionalArgIndex,
        app.rootCommand().addArg(Arg.positional("TWO", null, 1)),
    );

    app.deinit();
}

test "command that takes single value" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("PATH", null, 1));

    const matches = try app.parseFrom(&.{"test.txt"});
    try testing.expectEqualStrings("test.txt", matches.getSingleValue("PATH").?);

    app.deinit();
}

//  Positional argument can no longer take multiple values
//
// test "command that takes many values" {
//     var app = App.init(allocator, "rm", null);
//     errdefer app.deinit();

//     var paths = Arg.init("PATHS", null);
//     paths.setProperty(.takes_multiple_values);
//     paths.setProperty(.takes_value);

//     try app.rootCommand().addArg(paths);
//     app.rootCommand().setProperty(.takes_positional_arg);

//     const matches = try app.parseFrom(&.{ "a", "b", "c" });
//     try testing.expectEqualSlices([]const u8, &.{ "a", "b", "c" }, args.getMultiValues("PATHS").?);

//     app.deinit();
// }

//  Positional argument can no longer take multiple values
//
// test "command that takes many values using delimiter" {
//     var app = App.init(allocator, "rm", null);
//     errdefer app.deinit();

//     var paths = Arg.init("PATHS", null);
//     paths.setProperty(.takes_multiple_values);
//     paths.setValuesDelimiter(":");

//     try app.rootCommand().addArg(paths);
//     app.rootCommand().setProperty(.takes_positional_arg);

//     const matches = try app.parseFrom(&.{"a:b:c"});

//     // This gives weird error like:
//     // index 0 incorrect. expected { 97 }, found { 97 }
//     //try testing.expectEqualSlices([]const u8, &.{ "a", "b", "c" }, args.getMultiValues("PATHS").?);

//     const given_paths = args.getMultiValues("PATHS");
//     try testing.expectEqual(true, given_paths != null);
//     try testing.expectEqual(@as(usize, 3), given_paths.?.len);
//     try testing.expectEqualStrings("a", given_paths.?[0]);
//     try testing.expectEqualStrings("b", given_paths.?[1]);
//     try testing.expectEqualStrings("c", given_paths.?[2]);

//     app.deinit();
// }

test "command that takes required positional arg" {
    var app = App.init(allocator, "rm", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("PATH", null, null));
    app.rootCommand().setProperty(.positional_arg_required);
    try testing.expectError(error.PositionalArgumentNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "command requires subcommand" {
    var app = App.init(allocator, "git", null);
    errdefer app.deinit();

    try app.rootCommand().addSubcommand(app.createCommand("init", null));
    app.rootCommand().setProperty(.subcommand_required);
    try testing.expectError(error.SubcommandNotProvided, app.parseFrom(&.{}));

    app.deinit();
}

test "Option that does not takes value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.booleanOption("version", 'v', null));
    try testing.expectError(error.UnexpectedOptionValue, app.parseFrom(&.{"-v=13"}));

    app.deinit();
}

test "Option that takes single value" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.singleValueOption("output", 'o', null));
    try testing.expectError(error.OptionValueNotProvided, app.parseFrom(&.{"-o"}));

    app.deinit();
}

test "multiValuesOption provided with single value short" {
    var app = App.init(allocator, "clang", null);
    defer app.deinit();

    const srcs = Arg.multiValuesOption("sources", 's', null, 128);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);

    const matches_short = try app.parseFrom(&.{ "-s", "f1" });
    try testing.expectEqual(@as(usize, 1), matches_short.getMultiValues("sources").?.len);
}

test "multiValuesOption provided with single value long" {
    var app = App.init(allocator, "clang", null);
    defer app.deinit();

    const srcs = Arg.multiValuesOption("sources", 's', null, 128);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);

    const matches_short = try app.parseFrom(&.{ "--sources", "f1" });
    try testing.expectEqual(@as(usize, 1), matches_short.getMultiValues("sources").?.len);
}

test "multiValuesOption provided with multiple values short" {
    var app = App.init(allocator, "clang", null);
    defer app.deinit();

    const srcs = Arg.multiValuesOption("sources", 's', null, 128);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);
    const matches = try app.parseFrom(&.{ "-s", "f1", "f2", "f3", "f4", "f5" });

    try testing.expectEqual(@as(usize, 5), matches.getMultiValues("sources").?.len);
}

test "multiValuesOption provided with multiple values long" {
    var app = App.init(allocator, "clang", null);
    defer app.deinit();

    const srcs = Arg.multiValuesOption("sources", 's', null, 128);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);
    const matches = try app.parseFrom(&.{ "--sources", "f1", "f2", "f3", "f4", "f5" });

    try testing.expectEqual(@as(usize, 5), matches.getMultiValues("sources").?.len);
}

test "Option that takes many/multiple values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.init("sources", null);
    srcs.setShortName('s');
    srcs.setValuesDelimiter(":");
    srcs.setProperty(.takes_value);
    srcs.setProperty(.takes_multiple_values);

    // ex: clang sources...
    try app.rootCommand().addArg(srcs);
    const matches = try app.parseFrom(&.{ "-s", "f1", "f2", "f3", "f4", "f5" });

    try testing.expectEqual(@as(usize, 5), matches.getMultiValues("sources").?.len);

    app.deinit();
}

test "Option with min values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.init("sources", null);
    srcs.setShortName('s');
    srcs.setMinValues(2);
    srcs.setValuesDelimiter(":");
    srcs.setProperty(.takes_value);

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooFewOptionValue, app.parseFrom(&.{"-s=f1"}));

    app.deinit();
}

test "Option with max values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    var srcs = Arg.multiValuesOption("sources", 's', null, 5);
    srcs.setValuesDelimiter(":");

    try app.rootCommand().addArg(srcs);
    try testing.expectError(error.TooManyOptionValue, app.parseFrom(
        &.{"-s=f1:f2:f3:f4:f5:f6"},
    ));

    app.deinit();
}

test "Option with allowed values" {
    var app = App.init(allocator, "clang", null);
    errdefer app.deinit();

    const stdd = Arg.singleValueOptionWithValidValues(
        "std",
        null,
        null,
        &[_][]const u8{ "c99", "c11", "c17" },
    );

    try app.rootCommand().addArg(stdd);
    try testing.expectError(error.InvalidOptionValue, app.parseFrom(&.{"--std=c100"}));

    app.deinit();
}

test "passing positional argument before options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("PATH", null, null));
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));
    app.rootCommand().setProperty(.positional_arg_required);

    const matches = try app.parseFrom(&.{ ".", "-a" });
    try testing.expectEqualStrings(".", matches.getSingleValue("PATH").?);
    try testing.expectEqual(true, matches.containsArg("all"));

    app.deinit();
}

test "passing positional argument after options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("PATH", null, null));
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));

    const matches = try app.parseFrom(&.{ "-a", "." });
    try testing.expectEqualStrings(".", matches.getSingleValue("PATH").?);
    try testing.expectEqual(true, matches.containsArg("all"));

    app.deinit();
}

test "passing positional argument before and after options" {
    var app = App.init(allocator, "ls", null);
    errdefer app.deinit();

    try app.rootCommand().addArg(Arg.positional("PATH", null, null));
    try app.rootCommand().addArg(Arg.booleanOption("all", 'a', null));
    try app.rootCommand().addArg(Arg.booleanOption("one-line", '1', null));

    const matches = try app.parseFrom(&.{ "-1", ".", "-a" });
    try testing.expectEqualStrings(".", matches.getSingleValue("PATH").?);
    try testing.expectEqual(true, matches.containsArg("one-line"));
    try testing.expectEqual(true, matches.containsArg("all"));

    app.deinit();
}
