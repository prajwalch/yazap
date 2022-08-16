const std = @import("std");
const Arg = @import("../Arg.zig");
const Command = @import("../Command.zig");
const ParserError = @import("Parser.zig").Error;

const log = std.log.scoped(.zigarg);
pub const PrintError = std.fs.File.WriteError;

/// A structure for `Parser` to collect enough data
/// for generating error message
pub const ErrorContext = struct {
    /// Actual error that happened
    err: ParserError,
    /// The actual command argument which parser found just before error happened
    arg: ?*const Arg = null,
    /// The command whose argument parser was trying to parse
    cmd: ?*const Command = null,
    /// User provided raw argument
    provided_arg: []const u8,

    pub fn init() ErrorContext {
        return ErrorContext{ .err = undefined, .provided_arg = undefined };
    }

    pub inline fn setErr(self: *ErrorContext, err: ParserError) void {
        self.err = err;
    }

    pub inline fn setArg(self: *ErrorContext, arg: *const Arg) void {
        self.arg = arg;
    }

    pub inline fn setCmd(self: *ErrorContext, cmd: *const Command) void {
        self.cmd = cmd;
    }

    pub inline fn setProvidedArg(self: *ErrorContext, provided_arg: []const u8) void {
        self.provided_arg = provided_arg;
    }
};

pub fn print(err_ctx: ErrorContext) PrintError!void {
    switch (err_ctx.err) {
        ParserError.UnknownFlag => log.err("Unknown flag '{s}'\n", .{err_ctx.provided_arg}),
        ParserError.UnknownCommand => log.err("Unknown Command '{s}'\n", .{err_ctx.provided_arg}),
        ParserError.CommandArgumentNotProvided => log.err("The command '{s}' requires a value but none is provided\n", .{err_ctx.cmd.?.name}),
        ParserError.CommandSubcommandNotProvided => log.err("The command '{s}' requires a subcommand but none is provided", .{err_ctx.cmd.?.name}),
        ParserError.FlagValueNotProvided => log.err("The flag '{s}' takes a value but none is provided\n", .{err_ctx.provided_arg}),
        ParserError.UnneededAttachedValue => log.err("Arg '{s}' does not takes value but provided\n", .{err_ctx.arg.?.name}),
        ParserError.UnneededEmptyAttachedValue => log.err("Arg '{s}' does not takes value but provided empty value\n", .{err_ctx.arg.?.name}),
        ParserError.EmptyFlagValueNotAllowed => log.err("The flag '{s}' does not allow to pass empty value\n", .{err_ctx.arg.?.name}),
        ParserError.ProvidedValueIsNotValidOption => {
            log.err("Invalid value '{s}' for arg '{s}'\nValid options are:", .{
                err_ctx.provided_arg,
                err_ctx.arg.?.name,
            });

            // We don't need extra info like '[scoped] (..):' while printing just a simple value
            // therfore using directly stdout writer seems right solution here
            const stdout = std.io.getStdOut().writer();
            if (err_ctx.arg.?.allowed_values) |values| {
                for (values) |v| {
                    try stdout.print("{s}\n", .{v});
                }
            }
        },
        ParserError.TooManyArgValue => {
            const expected_num_values = if (err_ctx.arg.?.max_values) |max|
                max
            else if (err_ctx.arg.?.min_values) |min|
                min
            else
                1;

            log.err(
                \\Too many values for arg '{s}'
                \\
                \\Expected number of values to be {d}
            , .{ err_ctx.arg.?.name, expected_num_values });
        },
        ParserError.OutOfMemory => log.err("Out of memory\n", .{}),
    }
}
