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
/// Implicitly applies the `.takes_value` setting
pub fn setMinValues(self: *Arg, num: usize) void {
    if (num >= 1) {
        self.min_values = num;
        self.applySetting(.takes_value);
    }
}

/// Sets the maximum number of values an argument can take.
/// Implicitly applies the `.takes_value` setting
pub fn setMaxValues(self: *Arg, num: usize) void {
    self.max_values = num;
    self.applySetting(.takes_value);
}

/// Sets the allowed values for an argument.
/// Value outside of allowed values will be consider as error.
/// Implicitly applies the `.takes_value` setting
pub fn setAllowedValues(self: *Arg, values: []const []const u8) void {
    self.allowed_values = values;
    self.applySetting(.takes_value);
}

/// Sets the default separator between the values of an argument.
pub fn setDefaultValuesDelimiter(self: *Arg) void {
    self.setValuesDelimiter(DEFAULT_VALUES_DELIMITER);
}

/// Sets separator between the values of an argument.
/// Implicitly applies the `.takes_value` setting
pub fn setValuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
    self.applySetting(.takes_value);
}

pub fn verifyValueInAllowedValues(self: *const Arg, value_to_check: []const u8) bool {
    if (self.allowed_values) |values| {
        for (values) |value| {
            if (std.mem.eql(u8, value, value_to_check)) return true;
        }
        return false;
    } else {
        return true;
    }
}

pub fn applySetting(self: *Arg, option: Settings.Option) void {
    return self.settings.apply(option);
}

pub fn removeSetting(self: *Arg, option: Settings.Option) void {
    return self.settings.remove(option);
}

pub fn isSettingApplied(self: *const Arg, option: Settings.Option) bool {
    return self.settings.isApplied(option);
}

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
