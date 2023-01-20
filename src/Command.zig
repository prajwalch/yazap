const Command = @This();

const std = @import("std");
const help = @import("help.zig");
const Arg = @import("Arg.zig");
const MakeSettings = @import("settings.zig").MakeSettings;

const mem = std.mem;
const ArrayList = std.ArrayListUnmanaged;
const Allocator = mem.Allocator;
const Settings = MakeSettings(enum {
    takes_value,
    arg_required,
    subcommand_required,
    enable_help,
});

allocator: Allocator,
name: []const u8,
description: ?[]const u8 = null,
args: ArrayList(Arg) = .{},
options: ArrayList(Arg) = .{},
subcommands: ArrayList(Command) = .{},
settings: Settings = .{},

/// Creates a new instance of it
pub fn new(allocator: Allocator, name: []const u8, description: ?[]const u8) Command {
    return Command{ .allocator = allocator, .name = name, .description = description };
}

/// Release all allocated memory
pub fn deinit(self: *Command) void {
    self.args.deinit(self.allocator);
    self.options.deinit(self.allocator);

    for (self.subcommands.items) |*subcommand| {
        subcommand.deinit();
    }
    self.subcommands.deinit(self.allocator);
}

/// Appends the new arg into the args list
pub fn addArg(self: *Command, new_arg: Arg) !void {
    if ((new_arg.short_name == null) and (new_arg.long_name == null)) {
        try self.args.append(self.allocator, new_arg);
    } else {
        try self.options.append(self.allocator, new_arg);
    }
}

/// Appends args into the args list
pub fn addArgs(self: *Command, args: []Arg) !void {
    for (args) |arg| try self.addArg(arg);
}

/// Appends the new subcommand into the subcommands list
pub fn addSubcommand(self: *Command, new_subcommand: Command) !void {
    // Add help option for subcommand
    var subcmd = new_subcommand;
    help.enableFor(&subcmd);
    return self.subcommands.append(self.allocator, subcmd);
}

/// Appends the `subcommands` into the subcommands list
pub fn addSubcommands(self: *Command, subcommands: []Command) !void {
    for (subcommands) |subcmd| try self.addSubcommand(subcmd);
}

/// Create a new [Argument](/#root;Arg) with the given name and specifies that Command will take single value
pub fn takesSingleValue(self: *Command, arg_name: []const u8) !void {
    try self.takesNValues(arg_name, 1);
}

/// Creates an [Argument](/#root;Arg) with given name and specifies that command will take `n` values
pub fn takesNValues(self: *Command, arg_name: []const u8, n: usize) !void {
    var arg = Arg.new(arg_name, null);
    arg.setMinValues(1);
    arg.setMaxValues(n);
    if (n > 1) arg.setDefaultValuesDelimiter();

    try self.addArg(arg);
    self.setSetting(.takes_value);
}

pub fn setSetting(self: *Command, option: Settings.Option) void {
    return self.settings.set(option);
}

pub fn unsetSetting(self: *Command, option: Settings.Option) void {
    return self.settings.unset(option);
}

pub fn isSettingSet(self: *const Command, option: Settings.Option) bool {
    return self.settings.isSet(option);
}

pub fn countArgs(self: *const Command) usize {
    return (self.args.items.len);
}

pub fn countOptions(self: *const Command) usize {
    return (self.options.items.len);
}

pub fn countSubcommands(self: *const Command) usize {
    return (self.subcommands.items.len);
}

/// Linearly searches for an argument with short name equals to given `short_name`.
/// Returns a const pointer of a found argument otherwise null.
pub fn findShortOption(self: *const Command, short_name: u8) ?*const Arg {
    for (self.options.items) |*arg| {
        if (arg.short_name) |s| {
            if (s == short_name) return arg;
        }
    }
    return null;
}

/// Linearly searches for an argument with long name equals to given `long_name`.
/// Returns a const pointer of a found argument otherwise null.
pub fn findLongOption(self: *const Command, long_name: []const u8) ?*const Arg {
    for (self.options.items) |*arg| {
        if (arg.long_name) |l| {
            if (mem.eql(u8, l, long_name)) return arg;
        }
    }
    return null;
}

/// Linearly searches a sub-command with name equals to given `subcmd_name`.
/// Returns a const pointer of a found sub-command otherwise null.
pub fn findSubcommand(self: *const Command, provided_subcmd: []const u8) ?*const Command {
    for (self.subcommands.items) |*subcmd| {
        if (std.mem.eql(u8, subcmd.name, provided_subcmd)) {
            return subcmd;
        }
    }

    return null;
}

// TODO: Remove this function
pub fn getHelp(self: *const Command) help.Help {
    return help.Help.init(self.allocator, self, self.name) catch unreachable;
}

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
