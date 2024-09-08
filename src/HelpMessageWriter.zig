const HelpMessageWriter = @This();

const std = @import("std");
const Arg = @import("Arg.zig");
const BufferedWriter = std.io.BufferedWriter(4096, std.fs.File.Writer);
const Command = @import("Command.zig");
const ParsedCommand = @import("./parser/ParseResult.zig").ParsedCommand;

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
    const command = self.command.deref();

    if (command.countPositionalArgs() == 0) {
        return;
    }

    const writer = self.buffer.writer();
    try writer.writeAll("\nArgs:\n");

    for (command.positional_args.items) |arg| {
        var line = Line.init();
        try line.signature.addPadding(4);

        _ = try line.signature.writeAll(arg.name);

        if (arg.hasProperty(.takes_multiple_values)) {
            _ = try line.signature.writeAll("...");
        }

        const description = arg.description orelse {
            // Description is not set for the current arg.
            //
            // Print current line and move to the next iteration.
            try writer.print("{}", .{line});
            continue;
        };

        if (try line.description.writeAll(description)) |remaining_description| {
            // Description is too long to fit into the current line.
            //
            // First print the current line and then print the remaining
            // description at the new line but just below the first half description.
            try writer.print("{}", .{line});

            var new_line = Line.init();
            _ = try new_line.description.writeAll(remaining_description);

            try writer.print("{}", .{new_line});
        } else {
            // Description fits into the current line.
            //
            // Print the current line.
            try writer.print("{}", .{line});
        }
    }
}

fn writeSubcommands(self: *HelpMessageWriter) !void {
    if (self.command.deref().countSubcommands() == 0) {
        return;
    }

    const writer = self.buffer.writer();
    try writer.writeAll("\nCommands:\n");

    for (self.command.deref().subcommands.items) |*subcommand| {
        try self.writeSubcommand(subcommand);
    }
}

fn writeSubcommand(self: *HelpMessageWriter, subcommand: *const Command) !void {
    const writer = self.buffer.writer();

    var line = Line.init();
    try line.signature.addPadding(4);

    _ = try line.signature.writeAll(subcommand.name);

    const description = subcommand.description orelse {
        // Description is not set for the current subcommand.
        //
        // Print the current line and return.
        try writer.print("{}", .{line});
        return;
    };

    if (try line.description.writeAll(description)) |remaining_description| {
        // Description is too long to fit into the current line.
        //
        // First print the current line and then use the new line to print
        // the remaining description.
        try writer.print("{}", .{line});

        var new_line = Line.init();
        _ = try new_line.description.writeAll(remaining_description);

        try writer.print("{}", .{new_line});
    } else {
        // Description fits into the current line.
        //
        // Print the current line and move to the next iteration.
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
    try line.signature.addPadding(4);

    // Option name.
    if (option.short_name != null and option.long_name != null) {
        try line.signature.print(
            "-{c}, --{s}",
            .{ option.short_name.?, option.long_name.? },
        );
    } else if (option.short_name) |short_name| {
        try line.signature.print("-{c}", .{short_name});
    } else if (option.long_name) |long_name| {
        try line.signature.addPadding(4);
        try line.signature.print("--{s}", .{long_name});
    }

    // Value name.
    if (option.hasProperty(.takes_value)) {
        // Otherwise print the option actual value name or option name itself.
        const value_name = option.value_placeholder orelse option.name;
        try line.signature.print("=<{s}>", .{value_name});

        if (option.hasProperty(.takes_multiple_values)) {
            _ = try line.signature.writeAll("...");
        }
    }

    const description = option.description orelse {
        // Description is not set for the option.
        //
        // Print the current line and return.
        try writer.print("{}", .{line});
        return;
    };

    if (try line.description.writeAll(description)) |remaining_description| {
        // Description is too long to fit into the current line.
        //
        // First print the current line and then print the remaining
        // description at the new line but just below the first half description.
        try writer.print("{}", .{line});

        var new_line = Line.init();
        _ = try new_line.description.writeAll(remaining_description);

        try writer.print("{}", .{new_line});
    } else {
        // Description fits into the current line.
        //
        // Print the current line.
        try writer.print("{}", .{line});
    }

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
    /// A name of either subcommand or option including its value placeholder
    /// (`-t, --time=<SECS>`).
    const Signature = LineBlock(30);
    /// A description of either subcommand or option.
    const Description = LineBlock(70);

    signature: Signature,
    description: Description,

    /// Creates an empty line.
    pub fn init() Line {
        return Line{
            .signature = Signature.init(),
            .description = Description.init(),
        };
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
    }
};

/// Represents a certain space within a `Line` where signature or description
/// can be write.
fn LineBlock(comptime width: usize) type {
    return struct {
        const Self = @This();

        /// A character used for padding.
        const WHITE_SPACE = ' ';
        /// Used for storing content.
        const Buffer = std.BoundedArray(u8, width);

        buffer: Buffer,

        /// Creates an empty block having given width.
        pub fn init() Self {
            return Self{
                .buffer = Self.Buffer.init(0) catch unreachable,
            };
        }

        /// Adds the `n` number of padding.
        pub fn addPadding(self: *Self, n: usize) !void {
            if (n > self.buffer.capacity()) {
                return self.addPadding(self.remainingSpaceLength());
            }
            try self.buffer.appendNTimes(Self.WHITE_SPACE, n);
        }

        /// Appends the content based on the given format.
        fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
            try self.buffer.writer().print(fmt, args);
        }

        /// Appends the given content as-is.
        ///
        /// If the content is too long to fit into the buffer it writes upto to
        /// the writable portion and returns the remaining.
        pub fn writeAll(self: *Self, content: []const u8) !(?[]const u8) {
            const remaining_space_length = self.remainingSpaceLength();

            if (content.len <= remaining_space_length) {
                try self.buffer.appendSlice(content);
                return null;
            }

            const writeable_portion = content[0..remaining_space_length];
            const remaining_portion = content[remaining_space_length..];
            _ = try self.writeAll(writeable_portion);

            return remaining_portion;
        }

        /// Returns the total length of remaining space into the buffer.
        fn remainingSpaceLength(self: *const Self) usize {
            return self.buffer.capacity() - self.buffer.len;
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

            try writer.writeAll(mut_self.buffer.constSlice());
        }
    };
}
