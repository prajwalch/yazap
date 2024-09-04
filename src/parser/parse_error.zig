const std = @import("std");
const builtin = @import("builtin");

/// An error type returned by the `ParseErrorContext` printer.
pub const PrintError = std.fs.File.WriteFileError;
/// An error type returned by the parser.
pub const ParseError = error{
    UnrecognizedCommand,
    CommandArgumentNotProvided,
    CommandSubcommandNotProvided,
    UnrecognizedArgument,
    ArgumentValueNotProvided,
    UnexpectedArgumentValue,
    EmptyArgumentValue,
    InvalidArgumentValue,
    TooFewArgumentValue,
    TooManyArgumentValue,
};

/// Represents `ParseError` context.
///
/// This is used to store the error payload related to each error.
pub const ParseErrorContext = union(enum) {
    /// Unknown or undefined context.
    none,
    /// An unrecognized command.
    unrecognized_command: []const u8,
    /// A command which was expecting an argument.
    command_argument_not_provided: []const u8,
    /// A command which was expecting a subcommand.
    command_subcommand_not_provided: []const u8,
    /// An unrecognized argument (long or short).
    unrecognized_argument: []const u8,
    /// Name of an argument which was expecting a value.
    argument_value_not_provided: []const u8,
    /// A specified value for an argument which was not expected.
    unexpected_argument_value: struct {
        /// Name of an argument for which value was provided.
        argument: []const u8,
        /// Value which was provided.
        value: []const u8,
    },
    /// An argument was expecting non-empty value.
    empty_argument_value: []const u8,
    /// An invalid value for an argument.
    invalid_argument_value: struct {
        /// Name of an argument.
        argument: []const u8,
        /// Specified value.
        invalid_value: []const u8,
        /// List of acceptable values.
        valid_values: []const []const u8,
    },
    /// Specified values are not enough for an argument.
    too_few_argument_value: struct {
        /// Name of an argument.
        argument: []const u8,
        /// How much values were provided?.
        num_values: usize,
        /// Minimum number of values required for an argument.
        min_values: usize,
    },
    /// Specified values exceed the upper limitation.
    too_many_argument_value: struct {
        /// Name of an argument.
        argument: []const u8,
        /// How many values were provided?.
        num_values: usize,
        /// Upper limitation.
        max_values: usize,
    },
};

/// Prints the parse error context in a nice error message.
pub fn print(parse_error_context: ParseErrorContext) PrintError!void {
    var buffer = std.io.bufferedWriter(std.io.getStdErr().writer());
    const writer = buffer.writer();

    // Print the error prefix for nicer output.
    try writer.writeAll("error: ");

    switch (parse_error_context) {
        .none => {
            if (builtin.is_test) {
                return error.ParseErrorPrintReceivesAnEmptyContext;
            }
            return;
        },
        .unrecognized_command => |command| {
            try writer.print("unrecognized command '{s}'\n", .{command});
        },
        .command_argument_not_provided => |command| {
            try writer.print("command '{s}' expects a value to provide\n", .{command});
        },
        .command_subcommand_not_provided => |command| {
            try writer.print("command '{s}' expects a subcommand to provide\n", .{command});
        },
        .unrecognized_argument => |argument| {
            try writer.print("unrecognized argument '{s}'\n", .{argument});
        },
        .argument_value_not_provided => |argument| {
            try writer.print("argument '{s}' expects a value to provide\n", .{argument});
        },
        .unexpected_argument_value => |ctx| {
            try writer.print("argument '{s}' was not expecting a value '{s}'\n", ctx);
        },
        .empty_argument_value => |argument| {
            try writer.print("argument '{s}' expects a value to be non-empty\n", .{argument});
        },
        .invalid_argument_value => |ctx| {
            try writer.print(
                "'{s}' is invalid value for argument '{s}'\n\n",
                .{ ctx.invalid_value, ctx.argument },
            );
            try writer.writeAll("help: try to pass one of the following value:\n");

            for (ctx.valid_values) |valid_value| {
                try writer.print("\t{s}\n", .{valid_value});
            }
        },
        .too_few_argument_value => |ctx| {
            try writer.print(
                "argument '{s}' expects at least '{d}' values to provide\n\n",
                .{ ctx.argument, ctx.min_values },
            );
            try writer.print(
                "help: try adding '{d}' more value/s\n",
                .{ctx.min_values - ctx.num_values},
            );
        },
        .too_many_argument_value => |ctx| {
            try writer.print(
                "argument '{s}' only takes upto '{d}' values\n\n",
                .{ ctx.argument, ctx.max_values },
            );
            try writer.print(
                "help: try reducing '{d}' value/s\n",
                .{ctx.num_values - ctx.max_values},
            );
        },
    }
    try writer.writeAll("\ninfo: invoke the command with '-h' or '--h' to learn more.\n");
    try buffer.flush();
}
