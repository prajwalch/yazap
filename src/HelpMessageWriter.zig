const HelpMessageWriter = @This();

const std = @import("std");
const Arg = @import("Arg.zig");
const BufferedWriter = std.fs.File.Writer;
const Command = @import("Command.zig");
const ParsedCommand = @import("parser/ParseResult.zig").ParsedCommand;

/// The total number of space to use before any argument name.
///
/// **NOTE**: The argument refers to any argument not just the `Arg`.
const SIGNATURE_LEFT_PADDING = 4;

/// Used to store the help content before writing into the `stderr`.
writer: BufferedWriter = undefined,
/// Command whose help to write.
command: *const ParsedCommand = undefined,

pub fn init(command: *const ParsedCommand, buffer: []u8) HelpMessageWriter {
    return HelpMessageWriter{
        .writer = .init(std.fs.File.stderr(), buffer),
        .command = command,
    };
}

pub fn write(self: *HelpMessageWriter) !void {
    try self.writeDescription();
    try self.writeHeader();
    try self.writePositionalArgs();
    try self.writeSubcommands();
    try self.writeOptions();
    try self.writeFooter();

    try self.writer.interface.flush();
}

fn writeDescription(self: *HelpMessageWriter) !void {
    if (self.command.deref().description) |d| {
        const writer = &self.writer.interface;
        try writer.print("{s}\n\n", .{d});
        try writer.flush();
    }
}

fn writeHeader(self: *HelpMessageWriter) !void {
    const writer = &self.writer.interface;
    try writer.print("Usage: {s}", .{self.command.name()});

    const command = self.command.deref();

    if (command.countPositionalArgs() >= 1) {
        try writer.print(
            " {c}ARGS{c}",
            getBraces(command.hasProperty(.positional_arg_required)),
        );
    }

    if (command.countOptions() >= 1) {
        try writer.writeAll(" [OPTIONS]");
    }

    if (command.countSubcommands() >= 1) {
        try writer.print(
            " {c}COMMAND{c}",
            getBraces(command.hasProperty(.subcommand_required)),
        );
    }

    // End of line.
    try writer.writeByte('\n');

    try writer.flush();
}

fn writePositionalArgs(self: *HelpMessageWriter) !void {
    if (self.command.deref().countPositionalArgs() == 0) {
        return;
    }

    const writer = &self.writer.interface;
    try writer.writeAll("\nArgs:\n");

    for (self.command.deref().positional_args.items) |arg| {
        var line = Line{};
        line.init();
        line.signature.addPadding(SIGNATURE_LEFT_PADDING) catch {
            return error.WriteFailed;
        };
        try line.signature.writeAll(arg.name);

        if (arg.hasProperty(.takes_multiple_values)) {
            try line.signature.writeAll("...");
        }

        if (arg.description) |description| {
            try line.description.writeAll(description);
        }

        try writer.print("{f}", .{&line});
    }

    try writer.flush();
}

fn writeSubcommands(self: *HelpMessageWriter) !void {
    if (self.command.deref().countSubcommands() == 0) {
        return;
    }

    const writer = &self.writer.interface;
    try writer.writeAll("\nCommands:\n");

    for (self.command.deref().subcommands.items) |*subcommand| {
        var line = Line{};
        line.init();
        try line.signature.addPadding(SIGNATURE_LEFT_PADDING);
        try line.signature.writeAll(subcommand.name);

        if (subcommand.description) |description| {
            try line.description.writeAll(description);
        }

        try writer.print("{f}", .{&line});
    }

    try writer.flush();
}

fn writeOptions(self: *HelpMessageWriter) !void {
    if (self.command.deref().countOptions() == 0) {
        return;
    }

    const writer = &self.writer.interface;
    try writer.writeAll("\nOptions:\n");

    for (self.command.deref().options.items) |*option| {
        try self.writeOption(option);
    }

    const help = Arg.booleanOption("help", 'h', "Print this help and exit");
    try self.writeOption(&help);

    try writer.flush();
}

fn writeOption(self: *HelpMessageWriter, option: *const Arg) !void {
    const writer = &self.writer.interface;

    var line = Line{};
    line.init();
    try line.signature.addPadding(SIGNATURE_LEFT_PADDING);

    // Option name.
    if (option.short_name != null and option.long_name != null) {
        try line.signature.print(
            "-{c}, --{s}",
            .{ option.short_name.?, option.long_name.? },
        );
    } else if (option.short_name) |short_name| {
        try line.signature.print("-{c}", .{short_name});
    } else if (option.long_name) |long_name| {
        // When short name are not present extra padding is required to align
        // all the long name in the same line.
        //
        //     -t, --time
        //         --max-time
        //
        // If not set then it will look like:
        //
        //     -t, --time
        //     --max-time
        try line.signature.addPadding(SIGNATURE_LEFT_PADDING);
        try line.signature.print("--{s}", .{long_name});
    }

    // Value name.
    if (option.hasProperty(.takes_value)) {
        // Print the option actual value name or option name itself.
        const value_name = option.value_placeholder orelse option.name;
        try line.signature.print("=<{s}>", .{value_name});

        if (option.hasProperty(.takes_multiple_values)) {
            try line.signature.writeAll("...");
        }
    }

    // Description.
    if (option.description) |description| {
        try line.description.writeAll(description);
        try writer.print("{f}", .{&line});
    }

    if (option.valid_values) |valid_values| {
        // If the description is not set then print the values at the same line.
        if (option.description == null) {
            // Strangely this line was compiled on zig 0.14.1
            //try line.description.print("values: {s}", .{valid_values});
            try line.description.print("values: ", .{});
            for (valid_values, 0..) |v, i| {
                try line.description.print("{s}", .{v});
                if (i < valid_values.len-1) {
                    try line.description.print(" ", .{});
                }
            }
            return writer.print("{f}", .{&line});
        }

        // If the description is set then print the values at the new line
        // but just below the description.
        var new_line = Line{};
        new_line.init();
        try new_line.description.addPadding(2);
        // Strangely this line was compiled on zig 0.14.1
        //try new_line.description.print("values: {s}", .{valid_values});
        try new_line.description.print("values: ", .{});
        for (valid_values, 0..) |v, i| {
            try new_line.description.print("{s}", .{v});
            if (i < valid_values.len-1) {
                try new_line.description.print(" ", .{});
            }
        }
        try writer.print("{f}", .{&new_line});
    }

    try writer.flush();
}

fn writeFooter(self: *HelpMessageWriter) !void {
    const writer = &self.writer.interface;
    if (self.command.deref().countSubcommands() >= 1) {
        try writer.print(
            "\nRun '{s} <command>` with `-h/--h' flag to get help of any command.\n",
            .{self.command.name()},
        );
    }
    try writer.flush();
}

fn getBraces(required: bool) struct { u8, u8 } {
    return if (required) .{ '<', '>' } else .{ '[', ']' };
}

/// Represents a line in the terminal.
///
/// As compere to regular line composed of single row and multiple columns,
/// this line is composed of two blocks named `signature` and `description`.
const Line = struct {
    /// Represents the name of an argument.
    ///
    /// **NOTE**: The argument refers to any argument not just the `Arg`.
    const Signature = LineBlock(50, true);
    /// Represents the description of an argument.
    ///
    /// **NOTE**: The argument refers to any argument not just the `Arg`.
    const Description = LineBlock(500, false);

    /// Argument name or any other text which can be part of name.
    ///
    /// For e.x.: Option name and its value placeholder makes up single
    /// signature (`-t, --time=<SECS>`).
    signature: Signature = undefined,
    /// Argument description.
    description: Description = undefined,

    /// Creates an empty line.
    pub fn init(self: *Line) void {
        self.signature.init();
        self.description.init();
    }

    pub fn format(self: *Line, writer: *std.Io.Writer) error{WriteFailed}!void {
        try writer.print("{f}{f}\n", .{ &self.signature, &self.description });

        const overflow_signature = self.signature.overflowContent();
        const overflow_description = self.description.overflowContent();

        if (overflow_signature == null and overflow_description == null) {
            return;
        }

        var new_line = Line{};
        new_line.init();

        if (overflow_signature) |signature| {
            // FIXME: Inherit padding from the previous line (i.e. this line).
            new_line.signature.addPadding(SIGNATURE_LEFT_PADDING) catch {
                return error.WriteFailed;
            };
            try new_line.signature.writeAll(signature);
        }

        if (overflow_description) |description| {
            try new_line.description.writeAll(description);
        }

        try writer.print("{f}", .{&new_line});

        try writer.flush();
    }
};

/// Represents a discrete area within a `Line` where signature or description
/// can be write.
fn LineBlock(comptime width: usize, comptime fill_max_width: bool) type {
    return struct {
        const Self = @This();

        /// A character used for padding.
        const WHITE_SPACE = ' ';
        /// Used for storing content.
        const Array = std.ArrayList(u8);
        /// A custom writer over the `std.BoundedArray.Writer` for better error
        /// and word wrap handling.
        const ContentWriter = struct {
            context: *Self,
            interface: std.Io.Writer,

            pub fn init(context: *Self) ContentWriter {
                return .{
                    .context = context,
                    .interface = .{
                        .vtable = &.{
                            .drain = drain,
                            .sendFile = std.Io.Writer.unimplementedSendFile,
                        },
                        .buffer = &.{},
                    },
                };
            }

            pub fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
                const w: *ContentWriter = @alignCast(@fieldParentPtr("interface", io_w));
                for (data[0 .. data.len - 1]) |buf| {
                    if (buf.len == 0) continue;
                    const n = try w.context.writeContent(buf);
                    return io_w.consume(n);
                }
                const pattern = data[data.len - 1];
                if (pattern.len == 0 or splat == 0) return 0;
                const n = try w.context.writeContent(pattern);
                return io_w.consume(n);
            }
        };

        /// Required error type for the required method.
        const ContentWriteError = std.Io.Writer.Error;

        /// Content writer
        content_writer: ContentWriter = undefined,

        /// Content that fits into this block.
        visible_content_buffer: [width]u8 = undefined,
        visible_content: Array = undefined,
        /// Content that cannot fit into this block.
        overflow_content_buffer: [width]u8 = undefined,
        overflow_content: Array = undefined,

        /// Creates an empty block.
        fn init(self: *Self) void {
            self.content_writer = ContentWriter.init(self);
            self.visible_content = Array.initBuffer(&self.visible_content_buffer);
            self.overflow_content = Array.initBuffer(&self.overflow_content_buffer);
        }

        /// Returns the length of remaining space.
        fn remainingSpaceLength(self: *const Self) usize {
            return width - self.visible_content.items.len;
        }

        /// Returns the content that cannot fit into this block, if any.
        fn overflowContent(self: *const Self) ?[]const u8 {
            if (self.overflow_content.items.len == 0) {
                return null;
            }
            return self.overflow_content.items;
        }

        /// Adds the `n` number of space.
        fn addPadding(self: *Self, n: usize) !void {
            if (n > width) {
                return self.addPadding(self.remainingSpaceLength());
            }
            self.visible_content.appendNTimesAssumeCapacity(Self.WHITE_SPACE, n);
        }

        /// Appends the string based on the given format.
        fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
            try self.contentWriter().print(fmt, args);
            try self.contentWriter().flush();
        }

        /// Appends the given string as-is.
        fn writeAll(self: *Self, string: []const u8) !void {
            try self.contentWriter().writeAll(string);
            try self.contentWriter().flush();
        }

        /// Returns the content writer.
        fn contentWriter(self: *Self) *std.Io.Writer {
            return &self.content_writer.interface;
        }

        /// Writes the given bytes and returns the number of bytes written.
        fn writeContent(self: *Self, bytes: []const u8) ContentWriteError!usize {
            const remaining_space_length = self.remainingSpaceLength();

            if (bytes.len <= remaining_space_length) {
                self.visible_content.appendSliceAssumeCapacity(bytes);
                return bytes.len;
            }

            const writeable_portion = bytes[0..remaining_space_length];
            try self.writeAll(writeable_portion);

            const remaining_portion = bytes[remaining_space_length..];
            self.overflow_content.appendSliceAssumeCapacity(remaining_portion);

            return writeable_portion.len;
        }

        pub fn format(self: *Self, writer: *std.Io.Writer) !void {
            if (self.remainingSpaceLength() != 0 and fill_max_width) {
                self.addPadding(self.remainingSpaceLength()) catch {
                    return error.WriteFailed;
                };
            }

            try writer.writeAll(self.visible_content.items);

            try writer.flush();
        }
    };
}
