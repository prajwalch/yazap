const App = @This();

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArgMatches = @import("ArgMatches.zig");
const Command = @import("Command.zig");
const HelpMessageWriter = @import("HelpMessageWriter.zig");
const Parser = @import("parser/Parser.zig");
const ParseResult = @import("./parser/ParseResult.zig");
const YazapError = @import("error.zig").YazapError;

/// Top level allocator for the entire library.
allocator: Allocator,
/// Root command of the app.
command: Command,
/// Core structure containing parse result.
///
/// It is not intended for direct access, use `ArgMatches` instead.
parse_result: ?ParseResult = null,
/// Raw buffer containing command line arguments.
process_args: ?[]const [:0]u8 = null,

/// Creates a new instance of `App`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// ```
pub fn init(allocator: Allocator, name: []const u8, description: ?[]const u8) App {
    return App{
        .allocator = allocator,
        .command = Command.init(allocator, name, description),
    };
}

/// Deinitializes the library by releasing all the allocated memory and cleaning
/// up structures.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// defer app.deinit();
/// ```
pub fn deinit(self: *App) void {
    if (self.parse_result) |*parse_result| {
        parse_result.deinit();
    }
    if (self.process_args) |args| {
        std.process.argsFree(self.allocator, args);
    }
    self.command.deinit();
    self.parse_result = null;
}

/// Creates a new `Command` with given name and optional description.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// defer app.deinit();
///
/// var subcmd1 = app.createCommand("subcmd1", "First Subcommand");
/// ```
pub fn createCommand(self: *App, name: []const u8, description: ?[]const u8) Command {
    return Command.init(self.allocator, name, description);
}

/// Returns a pointer to the root `Command` of the application.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// // Add arguments and subcommands using `root`.
/// ```
pub fn rootCommand(self: *App) *Command {
    return &self.command;
}

/// Parses the arguments passed to the current process.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// // Add arguments and subcommands using `root`.
///
/// const matches = try app.parseProcess();
/// ```
pub fn parseProcess(self: *App) YazapError!ArgMatches {
    self.process_args = try std.process.argsAlloc(self.allocator);
    return self.parseFrom(self.process_args.?[1..]);
}

/// Parses the given arguments.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// // Add arguments and subcommands using `root`.
///
/// const matches = try app.parseFrom(&.{ "arg1", "--some-option" "subcmd" });
/// ```
pub fn parseFrom(self: *App, argv: []const [:0]const u8) YazapError!ArgMatches {
    var parser = Parser.init(self.allocator, argv, self.rootCommand());
    var result = parser.parse() catch |err| {
        // Don't clutter the test result with error messages.
        if (!builtin.is_test) {
            try parser.perror.print();
        }
        return err;
    };

    if (result.getCommandContainingHelpFlag()) |command| {
        var help_writer = HelpMessageWriter.init(command);
        try help_writer.write();
        result.deinit();
        self.deinit();
        std.process.exit(0);
    }

    self.parse_result = result;
    return ArgMatches{ .parse_result = &self.parse_result.? };
}

/// Displays the overall usage and description of the application.
///
/// **NOTE:** By default, the handling of the `-h` and `--help` options,
/// and the automatic display of the usage message are taken care of. Use this
/// function if you want to display the usage message when the `-h` or `--help`
/// options are not present on the command line.
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
/// const matches = try app.parseProcess();
///
/// if (!matches.containsArgs()) {
///     try app.displayHelp();
///     return;
/// }
/// ```
pub fn displayHelp(self: *App) YazapError!void {
    if (self.parse_result) |parse_result| {
        var help_writer = HelpMessageWriter.init(parse_result.getCommand());
        try help_writer.write();
    }
}

/// Displays the usage message of specified subcommand on the command line.
///
/// **NOTE:** By default, the handling of the `-h` and `--help` options,
/// and the automatic display of the usage message are taken care of. Use this
/// function if you want to display the usage message when the `-h` or `--help`
/// options are not present on the command line.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var subcmd = app.createCommand("subcmd", "Subcommand description");
/// try subcmd.addArg(Arg.booleanOption("verbose", 'v', "Enable verbose output"));
/// try root.addSubcommand(subcmd);
///
/// const matches = try app.parseProcess();
///
/// if (matches.subcommandMatches("subcmd")) |subcmd_matches| {
///     if (!subcmd_matches.containsArgs()) {
///         try app.displaySubcommandHelp();
/// }
/// ```
pub fn displaySubcommandHelp(self: *App) YazapError!void {
    const parse_result = self.parse_result orelse return;

    if (parse_result.getActiveSubcommand()) |subcmd| {
        var help_writer = HelpMessageWriter.init(subcmd);
        try help_writer.write();
    }
}
