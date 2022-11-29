//! Help message writer
const Help = @This();

// Help message is divided into 5 different sections:
// Description, Header, Commands, Options and Footer.
//
// DESCRIPTION
// _________________________
//
// Usage: <command name> ...
// _________________________
//
// Commands:
// ...
// _________________________
//
// Options:
// ...
// _________________________
//
// FOOTER

const std = @import("std");
const Command = @import("Command.zig");
const Braces = std.meta.Tuple(&[2]type{ u8, u8 });

pub const Options = struct {
    parent_cmds: ?[]const []const u8 = null,
    include_args: bool = false,
    include_subcmds: bool = false,
    include_flags: bool = false,
};

cmd: *const Command,
options: Options,

pub fn init(cmd: *const Command, options: ?Options) Help {
    return Help{ .cmd = cmd, .options = options orelse .{} };
}

pub fn writeAll(self: *Help, stream: anytype) !void {
    var buffer = std.io.bufferedWriter(stream);
    var writer = buffer.writer();

    try self.writeDescription(writer);
    try self.writeHeader(writer);
    try self.writeCommands(writer);
    try self.writeOptions(writer);
    try self.writeFooter(writer);

    try buffer.flush();
}

fn writeDescription(self: *Help, writer: anytype) !void {
    if (self.cmd.description) |des| {
        try writer.print("{s}", .{des});
        try writeNewLine(writer);
        try writeNewLine(writer);
    }
}

fn writeHeader(self: *Help, writer: anytype) !void {
    try writer.writeAll("Usage: ");

    if (self.options.parent_cmds) |parent_cmds| {
        for (parent_cmds) |parent_cmd|
            try writer.print("{s} ", .{parent_cmd});
    }
    try writer.print("{s} ", .{self.cmd.name});

    if (self.options.include_args) {
        const braces = getBraces(self.cmd.isSettingApplied(.arg_required));

        for (self.cmd.args.items) |arg| {
            try writer.print("{c}{s}{c} ", .{ braces[0], arg.name, braces[1] });
        }
    }

    if (self.options.include_flags)
        try writer.writeAll("[OPTIONS] ");
    if (self.options.include_subcmds) {
        const braces = getBraces(self.cmd.isSettingApplied(.subcommand_required));
        try writer.print("{c}COMMAND{c}", .{ braces[0], braces[1] });
    }
    try writeNewLine(writer);
    try writeNewLine(writer);
}

fn writeCommands(self: *Help, writer: anytype) !void {
    if (!(self.options.include_subcmds)) return;

    try writer.writeAll("Commands:");
    try writeNewLine(writer);

    for (self.cmd.subcommands.items) |subcmd| {
        try writer.print(" {s:<20} ", .{subcmd.name});
        if (subcmd.description) |d| try writer.print("{s}", .{d});
        try writeNewLine(writer);
    }
    try writeNewLine(writer);
}

fn writeOptions(self: *Help, writer: anytype) !void {
    try writer.writeAll("Options:");
    try writeNewLine(writer);

    if (self.options.include_flags) {
        for (self.cmd.options.items) |option| {
            if (option.short_name) |short_name|
                try writer.print(" -{c},", .{short_name});
            if (option.long_name) |long_name| {
                // When short name is null, add left padding in-order to
                // align all long names in the same line
                //
                // 6 comes by counting (` `) + (`-`) + (`x`) + (`,`)
                // where x is some short name
                const padding: usize = if (option.short_name == null) 6 else 0;
                try writer.print(" {[1]s:>[0]}{[2]s} ", .{ padding, "--", long_name });
            }

            if (option.isSettingApplied(.takes_value)) {
                // TODO: Add new `Arg.placeholderName()` to display proper placeholder

                // Required options: <A | B | C>
                if (option.allowed_values) |values| {
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
    }
    try writer.writeAll(" -h, --help\n\tPrint this help and exit\n");
}

fn writeFooter(self: *Help, writer: anytype) !void {
    if (self.options.include_subcmds) {
        try writeNewLine(writer);
        try writer.print(
            "Run '{s} <command> -h' or '{s} <command> --help' to get help for specific command",
            .{ self.cmd.name, self.cmd.name },
        );
        try writeNewLine(writer);
    }
}

inline fn getBraces(required: bool) Braces {
    return if (required) .{ '<', '>' } else .{ '[', ']' };
}

inline fn writeNewLine(writer: anytype) !void {
    return writer.writeByte('\n');
}
