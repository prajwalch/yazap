//! Represents the argument for your command.

const Arg = @This();
const std = @import("std");
const ArgsContext = @import("parser/ArgsContext.zig");

const Settings = struct {
    takes_value: bool = false,
    takes_multiple_values: bool = false,
    allow_empty_value: bool = false,
};

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
pub fn new(name: []const u8) Arg {
    return Arg{
        .name = name,
        .short_name = null,
        .long_name = null,
        .description = null,
        .allowed_values = null,
        .values_delimiter = null,
        .settings = Settings{},
    };
}

/// Sets the short name of the argument
pub fn shortName(self: *Arg, short_name: u8) void {
    self.short_name = short_name;
}

/// Sets the short name of the argument from the name
pub fn setShortNameFromName(self: *Arg) void {
    self.shortName(self.name[0]);
}

/// Sets the long name of the argument
pub fn longName(self: *Arg, long_name: []const u8) void {
    self.long_name = long_name;
}

pub fn setLongNameSameAsName(self: *Arg) void {
    self.longName(self.name);
}

pub fn setDescription(self: *Arg, description: []const u8) void {
    self.description = description;
}

/// Sets the minimum number of values required to provide for an argument.
/// Implicitly sets the `Arg.takesValue(true)`
pub fn minValues(self: *Arg, num: usize) void {
    if (num >= 1) {
        self.min_values = num;
        self.takesValue(true);
    }
}

/// Sets the maximum number of values an argument can take.
/// Implicitly sets the `Arg.takesValue(true)`
pub fn maxValues(self: *Arg, num: usize) void {
    self.max_values = num;
    self.takesValue(true);
}

/// Sets the allowed values for an argument.
/// Value outside of allowed values will be consider as error.
/// Implicitly sets the `Arg.takesValue(true)`
pub fn allowedValues(self: *Arg, values: []const []const u8) void {
    self.allowed_values = values;
    self.takesValue(true);
}

/// Sets separator between the values of an argument.
/// Implicitly sets the `Arg.takesValue(true)`
pub fn valuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
    self.takesValue(true);
}

/// Specifies that an argument will takes a value
pub fn takesValue(self: *Arg, b: bool) void {
    self.settings.takes_value = b;
}

/// Specifies that the argument will takes an unknown number of values.
/// You can use `Arg.maxValues(n)` to limit the number of values.
///
/// Note:
/// Values will continue to be consume until one of the following condition wiil satisfies:
/// 1. If another flag is found
/// 2. If parser reaches the end of raw argument
/// 3. If parser reaches the maximum number of values. Requires to explicitly set `Arg.maxValues(n)`
pub fn takesMultipleValues(self: *Arg, b: bool) void {
    self.settings.takes_multiple_values = b;
}

/// Specifies wether an argument can take a empty value or not
pub fn allowedEmptyValue(self: *Arg, b: bool) void {
    self.settings.allow_empty_value = b;
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

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
