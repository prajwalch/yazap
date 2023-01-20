//! Represents the argument for your command.

const Arg = @This();
const std = @import("std");
const MakeSettings = @import("settings.zig").MakeSettings;

const DEFAULT_VALUES_DELIMITER = ",";
const Settings = MakeSettings(enum {
    takes_value,
    takes_multiple_values,
    allow_empty_value,
});

name: []const u8,
short_name: ?u8,
long_name: ?[]const u8,
description: ?[]const u8,
min_values: ?usize = null,
max_values: ?usize = null,
allowed_values: ?[]const []const u8,
values_delimiter: ?[]const u8,
settings: Settings,

/// Creates a new instance of it
pub fn new(name: []const u8, description: ?[]const u8) Arg {
    return Arg{
        .name = name,
        .short_name = null,
        .long_name = null,
        .description = description,
        .allowed_values = null,
        .values_delimiter = null,
        .settings = Settings{},
    };
}

/// Sets the short name of the argument
pub fn setShortName(self: *Arg, short_name: u8) void {
    self.short_name = short_name;
}

/// Sets the short name of the argument from the name
pub fn setShortNameFromName(self: *Arg) void {
    self.setShortName(self.name[0]);
}

/// Sets the long name of the argument
pub fn setLongName(self: *Arg, long_name: []const u8) void {
    self.long_name = long_name;
}

pub fn setNameAsLongName(self: *Arg) void {
    self.setLongName(self.name);
}

/// Sets the minimum number of values required to provide for an argument.
pub fn setMinValues(self: *Arg, num: usize) void {
    self.min_values = if (num >= 1) num else null;
}

/// Sets the maximum number of values an argument can take.
pub fn setMaxValues(self: *Arg, num: usize) void {
    self.max_values = if (num >= 1) num else null;
}

/// Sets the allowed values for an argument.
/// Value outside of allowed values will be consider as error.
pub fn setAllowedValues(self: *Arg, values: []const []const u8) void {
    self.allowed_values = values;
}

/// Sets the default separator between the values of an argument.
pub fn setDefaultValuesDelimiter(self: *Arg) void {
    self.setValuesDelimiter(DEFAULT_VALUES_DELIMITER);
}

/// Sets separator between the values of an argument.
pub fn setValuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
}

pub fn setSetting(self: *Arg, option: Settings.Option) void {
    return self.settings.set(option);
}

pub fn unsetSetting(self: *Arg, option: Settings.Option) void {
    return self.settings.unset(option);
}

pub fn isSettingSet(self: *const Arg, option: Settings.Option) bool {
    return self.settings.isSet(option);
}

pub fn isValidValue(self: *const Arg, value_to_check: []const u8) bool {
    if (self.allowed_values) |values| {
        for (values) |value| {
            if (std.mem.eql(u8, value, value_to_check)) return true;
        }
        return false;
    }
    return true;
}

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
