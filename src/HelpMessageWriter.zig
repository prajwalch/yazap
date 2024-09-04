const HelpMessageWriter = @This();

const std = @import("std");
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
    const writer = self.buffer.writer();

    try self.writeDescription(writer);
    try self.writeHeader(writer);
    try self.writeCommands(writer);
    try self.writeOptions(writer);
    try self.writeFooter(writer);

    try self.buffer.flush();
}

fn writeDescription(self: *HelpMessageWriter, writer: anytype) !void {
    if (self.command.deref().description) |d| {
        try writer.print("{s}", .{d});
        try writeNewLine(writer);
        try writeNewLine(writer);
    }
}

fn writeHeader(self: *HelpMessageWriter, writer: anytype) !void {
    try writer.print("Usage: {s}", .{self.command.name()});
    try writer.writeByte(' ');

    const command = self.command.deref();

    if (command.countPositionalArgs() >= 1) {
        const braces = getBraces(command.hasProperty(.positional_arg_required));

        for (command.positional_args.items) |arg| {
            try writer.print("{c}{s}", .{ braces[0], arg.name });

            if (arg.hasProperty(.takes_multiple_values)) {
                try writer.writeAll("...");
            }

            try writer.print("{c} ", .{braces[1]});
        }
    }

    if (command.countOptions() >= 1) {
        try writer.writeAll("[OPTIONS] ");
    }

    if (command.countSubcommands() >= 1) {
        const braces = getBraces(command.hasProperty(.subcommand_required));
        try writer.print("{c}COMMAND{c}", .{ braces[0], braces[1] });
    }

    try writeNewLine(writer);
    try writeNewLine(writer);
}

fn writeCommands(self: *HelpMessageWriter, writer: anytype) !void {
    const command = self.command.deref();

    if (!(command.countSubcommands() >= 1)) return;

    try writer.writeAll("Commands:");
    try writeNewLine(writer);

    for (command.subcommands.items) |subcmd| {
        try writer.print(" {s:<20} ", .{subcmd.name});
        if (subcmd.description) |d| try writer.print("{s}", .{d});
        try writeNewLine(writer);
    }
    try writeNewLine(writer);
}

fn writeOptions(self: *HelpMessageWriter, writer: anytype) !void {
    const command = self.command.deref();
    if (!(command.countOptions() >= 1)) return;

    try writer.writeAll("Options:");
    try writeNewLine(writer);

    for (command.options.items) |option| {
        if (option.short_name) |short_name|
            try writer.print(" -{c},", .{short_name});

        const long_name = option.long_name orelse option.name;
        // When short name is null, add left padding in-order to
        // align all long names in the same line
        //
        // 6 comes by counting (` `) + (`-`) + (`x`) + (`,`)
        // where x is some short name
        const padding: usize = if (option.short_name == null) 6 else 0;
        try writer.print(" {[1]s:>[0]}{[2]s} ", .{ padding, "--", long_name });

        if (option.hasProperty(.takes_value)) {
            // TODO: Add new `Arg.placeholderName()` to display proper placeholder
            if (option.valid_values) |values| {
                try writer.writeByte('{');

                for (values, 0..) |value, idx| {
                    try writer.print("{s}", .{value});

                    // Only print '|' till second last option
                    if (idx < (values.len - 1)) {
                        try writer.writeAll("|");
                    }
                }
                try writer.writeByte('}');
            } else {
                try writer.print("<{s}>", .{option.name});
            }
        }

        if (option.description) |des_txt| {
            try writeNewLine(writer);
            try writer.print("\t{s}", .{des_txt});
            try writeNewLine(writer);
        }
        try writer.writeAll("\n");
    }
    try writer.writeAll(" -h, --help\n\tPrint help and exit");
    try writeNewLine(writer);
}

fn writeFooter(self: *HelpMessageWriter, writer: anytype) !void {
    const command = self.command.deref();

    if (command.countSubcommands() >= 1) {
        try writeNewLine(writer);
        try writer.print(
            "Run '{s} <command> -h' or '{s} <command> --help' to get help for specific command",
            .{ self.command.name(), self.command.name() },
        );
    }
    try writeNewLine(writer);
}

fn writeNewLine(writer: anytype) !void {
    try writer.writeByte('\n');
}

fn getBraces(required: bool) struct { u8, u8 } {
    return if (required) .{ '<', '>' } else .{ '[', ']' };
}
