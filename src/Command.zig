const Command = @This();

const std = @import("std");
const parser = @import("parser.zig");
const Flag = @import("Flag.zig");
const ArgMatches = @import("arg_matches.zig").ArgMatches;

const mem = std.mem;
const Allocator = mem.Allocator;

pub const SettingOption = enum {
    takes_value,
    flag_required,
    subcommand_required,
};

const Setting = struct {
    takes_value: bool,
    flag_required: bool,
    subcommand_required: bool,

    pub fn initDefault() Setting {
        return Setting{
            .takes_value = false,
            .flag_required = false,
            .subcommand_required = false,
        };
    }

    pub fn isOptionEnabled(self: *const Setting, option: SettingOption) bool {
        return switch (option) {
            .takes_value => self.takes_value,
            .flag_required => self.flag_required,
            .subcommand_required => self.subcommand_required,
        };
    }
};

allocator: Allocator,
name: []const u8,
about: ?[]const u8,
flags: ?std.ArrayList(Flag),
subcommands: ?std.ArrayList(Command),
setting: Setting,

pub fn new(allocator: Allocator, name: []const u8) Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .about = null,
        .flags = null,
        .subcommands = null,
        .setting = Setting.initDefault(),
    };
}

pub fn newWithHelpTxt(allocator: Allocator, name: []const u8, about: []const u8) Command {
    var self = Command.new(allocator, name);
    self.about = about;
    return self;
}

pub fn deinit(self: *Command) void {
    if (self.flags) |flags| {
        flags.deinit();
    }

    if (self.subcommands) |subcommands| {
        for (subcommands.items) |*subcommand| {
            subcommand.deinit();
        }
    }
}

pub fn addFlag(self: *Command, new_flag: Flag) !void {
    if (self.flags == null)
        self.flags = std.ArrayList(Flag).init(self.allocator);
    return self.flags.?.append(new_flag);
}

pub fn addSubcommand(self: *Command, new_subcommand: Command) !void {
    if (self.subcommands == null)
        self.subcommands = std.ArrayList(Command).init(self.allocator);
    return self.subcommands.?.append(new_subcommand);
}

pub fn takesValue(self: *Command, boolean: bool) void {
    self.setting.takes_value = boolean;
}

pub fn flagRequired(self: *Command, boolean: bool) void {
    self.setting.flag_required = boolean;
}

pub fn subcommandRequired(self: *Command, boolean: bool) void {
    self.setting.subcommand_required = boolean;
}

pub fn parse(self: *Command, argv: []const [:0]const u8) parser.Error!ArgMatches {
    return parser.parse(self.allocator, argv, self);
}

pub fn takesArg(self: *const Command) bool {
    // zig fmt: off
    return (self.isSettingEnabled(.takes_value)
            or self.flags != null
            or self.subcommands != null);
}

// zig fmt: on
pub fn isSettingEnabled(self: *const Command, setting_opt: SettingOption) bool {
    return self.setting.isOptionEnabled(setting_opt);
}
