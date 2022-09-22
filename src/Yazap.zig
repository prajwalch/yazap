const Yazap = @This();

const std = @import("std");
const Command = @import("Command.zig");
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

/// Returns a pointer of a root `Command`.
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
    var parser = Parser.init(self.allocator, Tokenizer.init(argv), self.rootCommand());
    var args_ctx = parser.parse() catch |e| {
        try parser.err_builder.logError();
        return e;
    };
    if (args_ctx.help) |*help| {
        try help.writeAll();
        args_ctx.deinit();
        self.deinit();
        std.process.exit(0);
    }
    self.args_ctx = args_ctx;
    return &self.args_ctx.?;
}

test "emit docs" {
    std.testing.refAllDecls(@This());
}
