//! Help message writer
const Help = @This();

const std = @import("std");
const Command = @import("Command.zig");
const Braces = std.meta.Tuple(&[2]type{ u8, u8 });

pub const Options = struct {
    include_args: bool = false,
    include_subcmds: bool = false,
    include_flags: bool = false,
};

cmd: *const Command,
options: Options = .{},

pub fn init(cmd: *const Command) Help {
    return Help{ .cmd = cmd };
}

// Help message is divided into 3 sections:  Header, Commands and Options.
// For each section there is a seperate functions for writing contents of them.
//
//  _________________________
// /                         \
// | Usage: <cmd name> ...   |
// |                         |
// | DESCRIPTION:            |
// | ...                     |
// |_________________________|
// |                         |
// | COMMANDS:               |
// | ...                     |
// |_________________________|
// |                         |
// | OPTIONS:                |
// | ...                     |
// \_________________________/

pub fn writeAll(self: *Help) !void {
    var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    var writer = buffer.writer();

    try self.writeHeader(writer);
    try self.writeCommands(writer);
    try self.writeOptions(writer);

    if (self.options.include_subcmds) {
        try writeNewLine(writer);
        try writer.print(
            "Run '{s} <command> -h' or '{s} <command> --help' to get help for specific command",
            .{ self.cmd.name, self.cmd.name },
        );
        try writeNewLine(writer);
    }
    try buffer.flush();
}

fn writeHeader(self: *Help, writer: anytype) !void {
    if (self.cmd.description) |des| {
        try writer.print("{s}", .{des});
        try writeNewLine(writer);
        try writeNewLine(writer);
    }
    try writer.print("Usage: {s} ", .{self.cmd.name});

    if (self.cmd.countArgs() >= 1) {
        self.options.include_flags = true;
        const braces = getBraces(self.cmd.setting.arg_required);

        for (self.cmd.args.items) |arg| {
            try writer.print("{c}{s}{c} ", .{ braces[0], arg.name, braces[1] });
        }
    }

    if (self.cmd.countOptions() >= 1) try writer.writeAll("[OPTIONS] ");

    if (self.cmd.countSubcommands() >= 1) {
        self.options.include_subcmds = true;
        const braces = getBraces(self.cmd.setting.subcommand_required);

        try writer.print("{c}COMMAND{c}", .{ braces[0], braces[1] });
        try writeNewLine(writer);
    }
    try writeNewLine(writer);
}

fn getBraces(required: bool) Braces {
    return if (required) .{ '<', '>' } else .{ '[', ']' };
}

fn writeCommands(self: *Help, writer: anytype) !void {
    if (!(self.options.include_subcmds)) return;

    try writer.writeAll("Commands:");
    try writeNewLine(writer);

    for (self.cmd.subcommands.items) |subcmd| {
        try writer.print(" {s}\t", .{subcmd.name});
        if (subcmd.description) |d| try writer.print("{s}", .{d});
        try writeNewLine(writer);
    }
    try writeNewLine(writer);
}

fn writeOptions(self: *Help, writer: anytype) !void {
    if (self.options.include_flags) {
        try writer.writeAll("Options:");
        try writeNewLine(writer);

        for (self.cmd.args.items) |arg| {
            if ((arg.short_name == null) and (arg.long_name == null)) continue;

            if (arg.short_name) |short_name|
                try writer.print(" -{c},", .{short_name});
            if (arg.long_name) |long_name|
                try writer.print(" --{s} ", .{long_name});

            if (arg.settings.takes_value) {
                // TODO: Add new `Arg.placeholderName()` to display proper placeholder

                // Required options: <A | B | C>
                if (arg.allowed_values) |values| {
                    try writer.writeByte('{');

                    for (values) |value, idx| {
                        try writer.print("{s}", .{value});

                        // Only print '|' till second last option
                        if (idx < (values.len - 1)) {
                            try writer.writeAll("|");
                        }
                    }
                    try writer.writeByte('}');
                } else {
                    // TODO: Find a better way to make UPPERCASE
                    var buff: [100]u8 = undefined;
                    var arg_name = std.ascii.upperString(&buff, arg.name);
                    std.mem.replaceScalar(u8, arg_name, '-', '_');
                    try writer.print("<{s}>", .{arg_name});
                }
            }

            if (arg.description) |des_txt| {
                try writeNewLine(writer);
                try writer.print("\t{s}", .{des_txt});
                try writeNewLine(writer);
            }
            try writer.writeAll("\n");
        }
    }
    try writer.writeAll(" -h, --help\n\tPrint this help and exit\n");
}

fn writeNewLine(writer: anytype) !void {
    return writer.writeByte('\n');
}
