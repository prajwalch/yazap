//! A structure for querying the parse result.
const ArgMatches = @This();

const std = @import("std");
const ParseResult = @import("parser/ParseResult.zig");

/// Core structure containing parse result.
///
/// It is not intended to use directly instead methods provided by this
/// structure should be use.
parse_result: *const ParseResult,

/// Checks whether any arguments were present on the command line.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.booleanOption("verbose", 'v', "Enable verbose output"));
/// try root.addSubcommand(app.createCommand("init-exe", "Initilize project"));
///
/// const matches = try app.parseProcess();
///
/// if (!matches.containsArgs()) {
///     try app.displayHelp();
///     return;
/// }
/// ```
pub fn containsArgs(self: *const ArgMatches) bool {
    return !self.parse_result.isEmpty();
}

/// Checks whether an option, positional argument or subcommand with the
/// specified name was present on the command line.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.booleanOption("verbose", 'v', "Enable verbose output"));
///
/// // Define a subcommand
/// var build_cmd = app.createCommand("build", "Build the project");
/// try build_cmd.addArg(Arg.booleanOption("release", 'r', "Build in release mode"));
/// try root.addSubcommand(build_cmd);
///
/// const matches = try app.parseProcess();
///
/// if (matches.containsArg("verbose")) {
///     // Handle verbose operation
/// }
///
/// if (matches.containsArg("build")) {
///     const build_cmd_matches = matches.subcommandMatches("build").?;
///
///     if (build_cmd_matches.containsArg("release")) {
///         // Build for release mode
///     }
/// }
///
/// ```
pub fn containsArg(self: *const ArgMatches, arg: []const u8) bool {
    if (self.parse_result.getArgs().contains(arg)) {
        return true;
    } else if (self.parse_result.getSubcommandParseResult()) |subcmd_result| {
        return std.mem.eql(u8, subcmd_result.getCommand().deref().name, arg);
    }
    return false;
}

/// Returns the value of an option or positional argument if it was present
/// on the command line; otherwise, returns `null`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.singleValueOption("config", 'c', "Config file"));
///
/// const matches = try app.parseProcess();
///
/// if (matches.getSingleValue("config")) |config_file| {
///     std.debug.print("Config file name: {s}", .{config_file});
/// }
/// ```
pub fn getSingleValue(self: *const ArgMatches, arg: []const u8) ?[]const u8 {
    if (self.parse_result.getArgs().get(arg)) |value| {
        if (value.isSingle()) return value.single;
    }
    return null;
}

/// Returns the values of an option if it was present on the command line;
/// otherwise, returns `null`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.multiValuesOption("nums", 'n', "Numbers to add", 2));
///
/// const matches = try app.parseProcess();
///
/// if (matches.getMultiValues("nums")) |numbers| {
///     std.debug.print("Add {s} + {s}", .{ numbers[0], numbers[1] });
/// }
/// ```
pub fn getMultiValues(self: *const ArgMatches, arg: []const u8) ?[][]const u8 {
    if (self.parse_result.getArgs().get(arg)) |value| {
        if (value.isMany()) return value.many.items[0..];
    }
    return null;
}

/// Returns the `ArgMatches` for a specific subcommand if it was present on
/// on the command line; otherwise, returns `null`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var build_cmd = app.createCommand("build", "Build the project");
/// try build_cmd.addArg(Arg.booleanOption("release", 'r', "Build in release mode"));
/// try build_cmd.addArg(Arg.singleValueOption("target", 't', "Build for given target"));
/// try root.addSubcommand(build_cmd);
///
/// const matches = try app.parseProcess();
///
/// if (matches.subcommandMatches("build")) |build_cmd_matches| {
///     if (build_cmd_matches.containsArg("release")) {
///         const target = build_cmd_matches.getSingleValue("target") orelse "default";
///         // Build for release mode to given target
///     }
/// }
///
/// ```
pub fn subcommandMatches(self: *const ArgMatches, subcmd: []const u8) ?ArgMatches {
    if (self.parse_result.getSubcommandParseResult()) |subcmd_result| {
        if (std.mem.eql(u8, subcmd_result.getCommand().deref().name, subcmd)) {
            return ArgMatches{ .parse_result = subcmd_result };
        }
    }
    return null;
}
