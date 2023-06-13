//! Represents the argument for your command.

const Arg = @This();
const std = @import("std");

const DEFAULT_VALUES_DELIMITER = ",";

const SettingsOption = enum {
    takes_value,
    takes_multiple_values,
    allow_empty_value,
};

name: []const u8,
short_name: ?u8,
long_name: ?[]const u8,
description: ?[]const u8,
min_values: ?usize = null,
max_values: ?usize = null,
allowed_values: ?[]const []const u8,
values_delimiter: ?[]const u8,
settings: std.EnumSet(SettingsOption),

// # Constructors

/// Creates a new instance of it
pub fn init(name: []const u8, description: ?[]const u8) Arg {
    return Arg{
        .name = name,
        .short_name = null,
        .long_name = null,
        .description = description,
        .allowed_values = null,
        .values_delimiter = null,
        .settings = .{},
    };
}

/// Creates a boolean option.
pub fn booleanOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.init(name, description);
    arg.setLongName(name);

    if (short_name) |n| arg.setShortName(n);

    return arg;
}

/// Creates a single argument option.
pub fn singleArgumentOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    return Arg.multiArgumentsOption(name, short_name, 1, description);
}

/// Creates a single argument option with valid values which user can pass.
pub fn singleArgumentOptionWithValidValues(
    name: []const u8,
    short_name: ?u8,
    values: []const []const u8,
    description: ?[]const u8,
) Arg {
    var arg = Arg.singleArgumentOption(name, short_name, description);
    arg.setAllowedValues(values);
    return arg;
}

/// Creates a multi arguments option.
pub fn multiArgumentsOption(
    name: []const u8,
    short_name: ?u8,
    max_values: usize,
    description: ?[]const u8,
) Arg {
    var arg = Arg.init(name, description);
    arg.setLongName(name);
    arg.setMinValues(1);
    arg.setMaxValues(max_values);
    arg.setSetting(.takes_value);

    if (short_name) |n| arg.setShortName(n);
    if (max_values > 1) arg.setDefaultValuesDelimiter();

    return arg;
}

// # Setters

/// Sets the short name of the argument
pub fn setShortName(self: *Arg, short_name: u8) void {
    self.short_name = short_name;
}

/// Sets the long name of the argument
pub fn setLongName(self: *Arg, long_name: []const u8) void {
    self.long_name = long_name;
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

pub fn setSetting(self: *Arg, option: SettingsOption) void {
    return self.settings.insert(option);
}

pub fn unsetSetting(self: *Arg, option: SettingsOption) void {
    return self.settings.remove(option);
}

// # Getters

pub fn isSettingSet(self: *const Arg, option: SettingsOption) bool {
    return self.settings.contains(option);
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
