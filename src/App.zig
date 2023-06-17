const App = @This();

const std = @import("std");
const help = @import("help.zig");
const Command = @import("Command.zig");
const Parser = @import("Parser.zig");
const ArgMatches = @import("arg_matches.zig").ArgMatches;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const YazapError = @import("error.zig").YazapError;

const Allocator = std.mem.Allocator;

allocator: Allocator,
command: Command,
subcommand_help: ?help.Help = null,
arg_matches: ?ArgMatches = null,
process_args: ?[]const [:0]u8 = null,

/// Creates a new instance of `App`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init("myls", "My custom ls");
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
/// var app = App.init("myls", "My custom ls");
/// defer app.deinit();
/// ```
pub fn deinit(self: *App) void {
    if (self.arg_matches) |*matches| matches.deinit();
    if (self.process_args) |pargs| std.process.argsFree(self.allocator, pargs);
    self.command.deinit();

    if (self.subcommand_help) |subcmd_help| {
        subcmd_help.parents.?.deinit();
    }
}

/// Creates a new `Command` with given name by setting a allocator to it
pub fn createCommand(self: *App, cmd_name: []const u8, cmd_description: ?[]const u8) Command {
    return Command.init(self.allocator, cmd_name, cmd_description);
}

/// Returns a pointer to a root `Command`.
pub fn rootCommand(self: *App) *Command {
    return &self.command;
}

/// Starts parsing the process arguments
pub fn parseProcess(self: *App) YazapError!(*const ArgMatches) {
    self.process_args = try std.process.argsAlloc(self.allocator);
    return self.parseFrom(self.process_args.?[1..]);
}

/// Starts parsing the given arguments
pub fn parseFrom(self: *App, argv: []const [:0]const u8) YazapError!(*const ArgMatches) {
    var parser = Parser.init(self.allocator, Tokenizer.init(argv), self.rootCommand());
    self.arg_matches = parser.parse() catch |e| {
        try parser.err.log(e);
        return e;
    };
    try self.handleHelpOption();
    return &self.arg_matches.?;
}

/// Displays the help message of root command
pub fn displayHelp(self: *App) !void {
    var cmd_help = help.Help.init(
        self.allocator,
        self.rootCommand(),
        self.rootCommand().name,
    ) catch unreachable;
    return cmd_help.writeAll(std.io.getStdErr().writer());
}

/// Displays the help message of subcommand if it is provided on command line
/// otherwise it will display nothing
pub fn displaySubcommandHelp(self: *App) !void {
    if (self.subcommand_help) |*h| return h.writeAll(std.io.getStdErr().writer());
}

fn handleHelpOption(self: *App) !void {
    // Set the `Help` of a subcommand present on the command line with the `-h` or `--help` option
    // remains null if none of the subcommands were present
    if (help.findSubcommand(self.rootCommand(), &self.arg_matches.?)) |subcmd| {
        self.subcommand_help = try help.Help.init(self.allocator, self.rootCommand(), subcmd);
    }
    try self.displayHelpAndExitIfFound();
}

fn displayHelpAndExitIfFound(self: *App) !void {
    var arg_matches = self.arg_matches.?;
    var help_displayed = false;

    if (arg_matches.isArgumentPresent("help")) {
        try self.displayHelp();
        help_displayed = true;
    } else {
        try self.displaySubcommandHelp();
        help_displayed = (self.subcommand_help != null);
    }

    if (help_displayed) {
        self.deinit();
        std.process.exit(0);
    }
}
