const std = @import("std");
const Command = @import("Command.zig");
const ArgMatches = @import("arg_matches.zig").ArgMatches;

const mem = std.mem;

/// Help message writer
///
/// Help message is divided into 5 different sections:
/// Description, Header, Commands, Options and Footer.
///
/// DESCRIPTION
/// _________________________
///
/// Usage: <command name> ...
/// _________________________
///
/// Commands:
/// ...
/// _________________________
///
/// Options:
/// ...
/// _________________________
///
/// FOOTER
pub const Help = struct {
    cmd: *const Command,
    parents: ?std.ArrayList([]const u8) = null,
    include_args: bool = false,
    include_subcmds: bool = false,
    include_flags: bool = false,

    pub fn init(allocator: mem.Allocator, root_cmd: *const Command, subcmd: []const u8) !Help {
        var self = Help{ .cmd = root_cmd };

        if (!mem.eql(u8, root_cmd.name, subcmd)) {
            self.parents = std.ArrayList([]const u8).init(allocator);
            try self.setCommandAndItsParents(root_cmd, subcmd);
        }
        self.include_args = (self.cmd.countPositionalArgs() >= 1);
        self.include_subcmds = (self.cmd.countSubcommands() >= 1);
        self.include_flags = (self.cmd.countOptions() >= 1);
        return self;
    }

    fn setCommandAndItsParents(self: *Help, parent_cmd: *const Command, subcmd_name: []const u8) mem.Allocator.Error!void {
        try self.parents.?.append(parent_cmd.name);

        for (parent_cmd.subcommands.items) |*subcmd| {
            if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
                self.cmd = subcmd;
                break;
            }
            try setCommandAndItsParents(self, subcmd, subcmd_name);
            // Command is already found; stop searching
            if (mem.eql(u8, self.cmd.name, subcmd_name)) break;

            _ = self.parents.?.popOrNull();
        }
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

        try self.writeParents(writer);
        try writer.print("{s} ", .{self.cmd.name});

        if (self.include_args) {
            const braces = getBraces(self.cmd.hasProperty(.positional_arg_required));

            for (self.cmd.positional_args.items) |arg| {
                try writer.print("{c}{s}", .{ braces[0], arg.name });
                if (arg.hasProperty(.takes_multiple_values))
                    try writer.writeAll("...");
                try writer.print("{c} ", .{braces[1]});
            }
        }

        if (self.include_flags)
            try writer.writeAll("[OPTIONS] ");
        if (self.include_subcmds) {
            const braces = getBraces(self.cmd.hasProperty(.subcommand_required));
            try writer.print("{c}COMMAND{c}", .{ braces[0], braces[1] });
        }
        try writeNewLine(writer);
        try writeNewLine(writer);
    }

    fn getBraces(required: bool) struct { u8, u8 } {
        return if (required) .{ '<', '>' } else .{ '[', ']' };
    }

    fn writeParents(self: *Help, writer: anytype) !void {
        if (self.parents) |parents| {
            for (parents.items) |parent_cmd|
                try writer.print("{s} ", .{parent_cmd});
        }
    }

    fn writeCommands(self: *Help, writer: anytype) !void {
        if (!self.include_subcmds) return;

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
        if (!self.include_flags) return;

        try writer.writeAll("Options:");
        try writeNewLine(writer);

        for (self.cmd.options.items) |option| {
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
    }

    fn writeFooter(self: *Help, writer: anytype) !void {
        if (self.include_subcmds) {
            try writeNewLine(writer);
            try writer.print(
                "Run '{s} <command> -h' or '{s} <command> --help' to get help for specific command",
                .{ self.cmd.name, self.cmd.name },
            );
        }
        try writeNewLine(writer);
    }

    fn writeNewLine(writer: anytype) !void {
        return writer.writeByte('\n');
    }
};

/// Returns which subcommand is active on command line with `-h` or `--help` option
/// null if none of the subcommands were present
pub fn findSubcommand(root_cmd: *const Command, matches: *ArgMatches) ?[]const u8 {
    if ((matches.subcommand != null) and (matches.subcommand.?.matches != null)) {
        const subcmd_name = matches.subcommand.?.name;
        const subcmd_matches = &matches.subcommand.?.matches.?;

        if (subcmd_matches.isPresent("help")) {
            return subcmd_name;
        } else {
            // If current subcommand's arg doesnot have `help` option
            // start to look its child subcommand's arg. (This happens recursively)
            return findSubcommand(root_cmd, subcmd_matches);
        }
    }
    return null;
}
