const HelpMessageWriter = @This();

const std = @import("std");
const Arg = @import("Arg.zig");
const BufferedWriter = std.io.BufferedWriter(4096, std.fs.File.Writer);
const Command = @import("Command.zig");
const ParsedCommand = @import("parser/ParseResult.zig").ParsedCommand;

/// The total number of space to use before any argument name.
///
/// **NOTE**: The argument refers to any argument not just the `Arg`.
const SIGNATURE_LEFT_PADDING = 4;

/// Used to store the help content before writing into the `stderr`.
buffer: BufferedWriter,
/// Command whose help to write.
command: *const ParsedCommand,

pub fn init(command: *const ParsedCommand) HelpMessageWriter {
    return HelpMessageWriter{
        .buffer = std.io.bufferedWriter(
            std.io.getStdErr().writer(),
        ),
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

    try self.buffer.flush();
}

fn writeDescription(self: *HelpMessageWriter) !void {
    const writer = self.buffer.writer();

    if (self.command.deref().description) |d| {
        try writer.print("{s}\n\n", .{d});
    }
}

fn writeHeader(self: *HelpMessageWriter) !void {
    const writer = self.buffer.writer();
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
}

fn writePositionalArgs(self: *HelpMessageWriter) !void {
    if (self.command.deref().countPositionalArgs() == 0) {
        return;
    }

    const writer = self.buffer.writer();
    try writer.writeAll("\nArgs:\n");

    for (self.command.deref().positional_args.items) |arg| {
        var line = Line.init();
        try line.signature.addPadding(SIGNATURE_LEFT_PADDING);
        try line.signature.writeAll(arg.name);

        if (arg.hasProperty(.takes_multiple_values)) {
            try line.signature.writeAll("...");
        }

        if (arg.description) |description| {
            try line.description.writeAll(description);
        }

        try writer.print("{}", .{line});
    }
}

fn writeSubcommands(self: *HelpMessageWriter) !void {
    if (self.command.deref().countSubcommands() == 0) {
        return;
    }

    const writer = self.buffer.writer();
    try writer.writeAll("\nCommands:\n");

    for (self.command.deref().subcommands.items) |*subcommand| {
        var line = Line.init();
        try line.signature.addPadding(SIGNATURE_LEFT_PADDING);
        try line.signature.writeAll(subcommand.name);

        if (subcommand.description) |description| {
            try line.description.writeAll(description);
        }

        try writer.print("{}", .{line});
    }
}

fn writeOptions(self: *HelpMessageWriter) !void {
    if (self.command.deref().countOptions() == 0) {
        return;
    }

    const writer = self.buffer.writer();
    try writer.writeAll("\nOptions:\n");

    for (self.command.deref().options.items) |*option| {
        try self.writeOption(option);
    }

    const help = Arg.booleanOption("help", 'h', "Print this help and exit");
    try self.writeOption(&help);
}

fn writeOption(self: *HelpMessageWriter, option: *const Arg) !void {
    const writer = self.buffer.writer();

    var line = Line.init();
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
    }

    try writer.print("{}", .{line});

    // If the acceptable values are set for the option, print them at the new
    // line but just below the description.
    if (option.valid_values) |valid_values| {
        var new_line = Line.init();
        try new_line.description.addPadding(2);
        try new_line.description.print("values: {s}", .{valid_values});

        try writer.print("{}", .{new_line});
    }
}

fn writeFooter(self: *HelpMessageWriter) !void {
    if (self.command.deref().countSubcommands() >= 1) {
        try self.buffer.writer().print(
            "\nRun '{s} <command>` with `-h/--h' flag to get help of any command.\n",
            .{self.command.name()},
        );
    }
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
    const Signature = LineBlock(30);
    /// Represents the description of an argument.
    ///
    /// **NOTE**: The argument refers to any argument not just the `Arg`.
    const Description = LineBlock(80);

    /// Argument name or any other text which can be part of name.
    ///
    /// For e.x.: Option name and its value placeholder makes up single
    /// signature (`-t, --time=<SECS>`).
    signature: Signature,
    /// Argument description.
    description: Description,

    /// Creates an empty line.
    pub fn init() Line {
        return Line{ .signature = Signature.init(), .description = Description.init() };
    }

    pub fn format(
        self: Line,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{}{}\n", .{ self.signature, self.description });

        const overflow_signature = self.signature.overflowContent();
        const overflow_description = self.description.overflowContent();

        if (overflow_signature == null and overflow_description == null) {
            return;
        }

        var new_line = Line.init();

        if (overflow_signature) |signature| {
            // FIXME: Inherit padding from the previous line (i.e. this line).
            try new_line.signature.addPadding(SIGNATURE_LEFT_PADDING);
            try new_line.signature.writeAll(signature);
        }

        if (overflow_description) |description| {
            try new_line.description.writeAll(description);
        }

        try writer.print("{}", .{new_line});
    }
};

/// Represents a discrete area within a `Line` where signature or description
/// can be write.
fn LineBlock(comptime width: usize) type {
    return struct {
        const Self = @This();

        /// A character used for padding.
        const WHITE_SPACE = ' ';
        /// Used for storing content.
        const Array = std.BoundedArray(u8, width);

        /// Content that fits into this block.
        visible_content: Array = Array{},
        /// Content that cannot fit into this block.
        overflow_content: Array = Array{},

        /// Creates an empty block.
        fn init() Self {
            return Self{};
        }

        /// Returns the length of remaining space.
        fn remainingSpaceLength(self: *const Self) usize {
            return width - self.visible_content.len;
        }

        /// Returns the content that cannot fit into this block, if any.
        fn overflowContent(self: *const Self) ?[]const u8 {
            if (self.overflow_content.len == 0) {
                return null;
            }
            return self.overflow_content.constSlice();
        }

        /// Adds the `n` number of space.
        fn addPadding(self: *Self, n: usize) !void {
            if (n > width) {
                return self.addPadding(self.remainingSpaceLength());
            }
            try self.visible_content.appendNTimes(Self.WHITE_SPACE, n);
        }

        /// Appends the string based on the given format.
        fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
            try self.visible_content.writer().print(fmt, args);
        }

        /// Appends the given string as-is.
        fn writeAll(self: *Self, string: []const u8) !void {
            const remaining_space_length = self.remainingSpaceLength();

            if (string.len <= remaining_space_length) {
                return self.visible_content.appendSlice(string);
            }

            const writeable_portion = string[0..remaining_space_length];
            try self.writeAll(writeable_portion);

            const remaining_portion = string[remaining_space_length..];
            try self.overflow_content.appendSlice(remaining_portion);
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var mut_self = self;

            if (mut_self.remainingSpaceLength() != 0) {
                mut_self.addPadding(mut_self.remainingSpaceLength()) catch {};
            }

            try writer.writeAll(mut_self.visible_content.constSlice());
        }
    };
}
