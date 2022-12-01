const Yazap = @This();

const std = @import("std");
const help = @import("help.zig");
const Command = @import("Command.zig");
//const Help = @import("Help.zig");
const Parser = @import("parser/Parser.zig");
const ArgsContext = @import("parser/ArgsContext.zig");
const Tokenizer = @import("parser/tokenizer.zig").Tokenizer;
const PrintError = @import("parser/ErrorBuilder.zig").PrintError;

const Allocator = std.mem.Allocator;

pub const Error = error{
    InvalidCmdLine,
    Overflow,
} || Parser.Error || PrintError;

allocator: Allocator,
command: Command,
subcommand_help: ?help.Help = null,
args_ctx: ?ArgsContext = null,
process_args: ?[]const [:0]u8 = null,

pub fn init(
    allocator: Allocator,
    cmd_name: []const u8,
    description: ?[]const u8,
) Yazap {
    return Yazap{
        .allocator = allocator,
        .command = blk: {
            var cmd = Command.new(allocator, cmd_name);
            cmd.description = description;
            break :blk cmd;
        },
    };
}

/// Deinitialize all the structures of `yazap` and release all the memory used by them
pub fn deinit(self: *Yazap) void {
    if (self.args_ctx) |*ctx| ctx.deinit();
    if (self.process_args) |pargs| std.process.argsFree(self.allocator, pargs);
    self.command.deinit();
}

/// Creates a new `Command` with given name by setting a allocator to it
pub fn createCommand(self: *Yazap, cmd_name: []const u8, cmd_description: ?[]const u8) Command {
    var cmd = Command.new(self.allocator, cmd_name);
    cmd.description = cmd_description;
    return cmd;
}

/// Returns a pointer to a root `Command`.
pub fn rootCommand(self: *Yazap) *Command {
    return &self.command;
}

/// Starts parsing the process arguments
pub fn parseProcess(self: *Yazap) Error!(*const ArgsContext) {
    self.process_args = try std.process.argsAlloc(self.allocator);
    return self.parseFrom(self.process_args.?[1..]);
}

/// Starts parsing the given arguments
pub fn parseFrom(self: *Yazap, argv: []const [:0]const u8) Error!(*const ArgsContext) {
    help.enableFor(&self.command);

    var parser = Parser.init(self.allocator, Tokenizer.init(argv), self.rootCommand());
    self.args_ctx = parser.parse() catch |e| {
        try parser.err_builder.logError();
        return e;
    };

    // Set the `Help` of a subcommand present on the command line with the `-h` or `--help` option
    // remains null if none of the subcommands were present
    self.subcommand_help = help.findSubcommandHelp(&self.command, &self.args_ctx.?);
    try self.displayHelpAndExitIfFound();
    return &self.args_ctx.?;
}

/// Displays the help message of root command
pub fn displayHelp(self: *Yazap) !void {
    return self.command.getHelp().writeAll(std.io.getStdOut().writer());
}

/// Displays the help message of subcommand if it is provided on command line
/// otherwise it will display nothing
pub fn displaySubcommandHelp(self: *Yazap) !void {
    if (self.subcommand_help) |*h| return h.writeAll(std.io.getStdOut().writer());
}

fn displayHelpAndExitIfFound(self: *Yazap) !void {
    var args_ctx = self.args_ctx.?;
    var help_displayed = false;

    if (args_ctx.isPresent("help")) {
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

test "emit docs" {
    std.testing.refAllDecls(@This());
}
