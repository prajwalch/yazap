const HelpMessageWriter = @This();

const std = @import("std");
const Arg = @import("Arg.zig");
const BufferedWriter = std.io.BufferedWriter(4096, std.fs.File.Writer);
const ParsedCommand = @import("./parser/ParseResult.zig").ParsedCommand;

/// The immediate buffer.
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
    try self.writeCommands();
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
        const braces = getBraces(command.hasProperty(.positional_arg_required));

        for (command.positional_args.items) |arg| {
            try writer.writeByte(' ');
            try writer.writeByte(braces[0]);

            try writer.print("{s}", .{arg.name});
            if (arg.hasProperty(.takes_multiple_values)) {
                try writer.writeAll("...");
            }

            try writer.writeByte(braces[1]);
        }
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

fn writeCommands(self: *HelpMessageWriter) !void {
    const writer = self.buffer.writer();
    const command = self.command.deref();

    if (command.countSubcommands() == 0) {
        return;
    }

    try writer.writeAll("\nCommands:\n");
    const right_padding: usize = if (command.countOptions() == 0) 10 else 30;

    for (command.subcommands.items) |subcmd| {
        try writer.print("    {[0]s:<[1]}", .{ subcmd.name, right_padding });

        if (subcmd.description) |d| {
            try writer.print("\t\t{s}", .{d});
        }
        try writer.writeByte('\n');
    }
}

fn writeOptions(self: *HelpMessageWriter) !void {
    const writer = self.buffer.writer();
    const command = self.command.deref();

    if (command.countOptions() == 0) {
        return;
    }

    try writer.writeAll("\nOptions:\n");
    for (command.options.items) |*option| {
        try self.writeOption(option);
    }

    const help = Arg.booleanOption("help", 'h', "Print this help and exit");
    try self.writeOption(&help);
}

fn writeOption(self: *HelpMessageWriter, option: *const Arg) !void {
    const writer = self.buffer.writer();

    // Signature refers to the option name (short and long) and its value name
    // if available.
    //
    // For e.x.: -h, --help             <description>
    //           -f, --file <FILE>      <description>
    //           ^---signature---^
    //
    // Signature pattern makes so much easy to add padding between it and the
    // description since we will only have two components to handle.
    var signature_buffer = try std.BoundedArray(u8, 100).init(50);
    var signature_writer = signature_buffer.writer();

    // Option name.
    if (option.short_name != null and option.long_name != null) {
        try signature_writer.print(
            "-{c}, --{s}",
            .{ option.short_name.?, option.long_name.? },
        );
    } else if (option.short_name) |short_name| {
        try signature_writer.print("-{c}", .{short_name});
    } else if (option.long_name) |long_name| {
        try signature_writer.print("    --{s}", .{long_name});
    }

    // Value name.
    if (option.hasProperty(.takes_value)) {
        try signature_writer.writeByte('=');

        // If the option has set acceptable values, print that.
        if (option.valid_values) |valid_values| {
            try signature_writer.writeByte('<');

            for (valid_values, 0..) |value, idx| {
                try signature_writer.print("{s}", .{value});

                // Don't print `|` at first and last.
                //
                // For e.x.: --format=<json|toml|yaml>
                if (idx < (valid_values.len - 1)) {
                    try signature_writer.writeByte('|');
                }
            }

            try signature_writer.writeByte('>');
        } else {
            // Otherwise print the option name.
            //
            // TODO: Add new `Arg.placeholderName()` to display correct value
            //       or placeholder name. For e.x.: --time=SECS.
            try signature_writer.print("<{s}>", .{option.name});

            if (option.hasProperty(.takes_multiple_values)) {
                try signature_writer.writeAll("...");
            }
        }
    }

    // First write the signature into the buffer with some padding.
    try writer.print("    {s:<80}", .{signature_buffer.constSlice()});

    // Then write the description.
    if (option.description) |description| {
        try writer.print("\t\t{s}", .{description});
    }

    // End of line.
    try writer.writeByte('\n');
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
