//! Represents the argument for your command.

const Arg = @This();
const std = @import("std");

const DEFAULT_VALUES_DELIMITER = ",";

pub const Property = enum {
    takes_value,
    takes_multiple_values,
    allow_empty_value,
};

name: []const u8,
description: ?[]const u8,
short_name: ?u8 = null,
long_name: ?[]const u8 = null,
min_values: ?usize = null,
max_values: ?usize = null,
valid_values: ?[]const []const u8 = null,
values_delimiter: ?[]const u8 = null,
index: ?usize = null,
properties: std.EnumSet(Property) = .{},

// # Constructors

/// Creates a new instance of it
pub fn init(name: []const u8, description: ?[]const u8) Arg {
    return Arg{ .name = name, .description = description };
}

/// Creates a boolean option.
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.booleanOption("version", 'v', "Show version number"));
/// ```
pub fn booleanOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    return arg;
}

/// Creates a single argument option.
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.singleArgumentOption("port", 'p', "Port number to bind"));
/// ```
pub fn singleArgumentOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    arg.addProperty(.takes_value);
    return arg;
}

/// Creates a single argument option with valid values which user can pass.
pub fn singleArgumentOptionWithValidValues(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    values: []const []const u8,
) Arg {
    var arg = Arg.singleArgumentOption(name, short_name, description);
    arg.setValidValues(values);
    return arg;
}

/// Creates a multi arguments option.
pub fn multiArgumentsOption(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    max_values: usize,
) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    arg.setMinValues(1);
    arg.setMaxValues(max_values);
    arg.setDefaultValuesDelimiter();
    arg.addProperty(.takes_value);
    return arg;
}

/// Creates a multi arguments option with valid values which user can pass.
pub fn multiArgumentsOptionWithValidValues(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    max_values: usize,
    values: []const []const u8,
) Arg {
    var arg = Arg.multiArgumentsOption(name, short_name, max_values, description);
    arg.setValidValues(values);
    return arg;
}

/// Creates a positional argument.
/// The index represents the position of your argument starting from **1**.
///
/// NOTE: Index is optional so by default it will be assigned in order of evalution.
///
/// ```zig
/// Order dependent
/// try root.addArg(Arg.positional("ONE", null, null));
/// try root.addArg(Arg.positional("TWO", null, null));
/// try root.addArg(Arg.positional("THREE", null, null));
///
/// // Equivalent but order independent
/// try root.addArg(Arg.positional("THREE", null, 3));
/// try root.addArg(Arg.positional("TWO", null, 2));
/// try root.addArg(Arg.positional("ONE", null, 1));
/// ```
pub fn positional(name: []const u8, description: ?[]const u8, index: ?usize) Arg {
    var arg = Arg.init(name, description);

    if (index) |i| {
        arg.setIndex(i);
    }
    arg.addProperty(.takes_value);
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

/// Sets the valid values for an argument.
pub fn setValidValues(self: *Arg, values: []const []const u8) void {
    self.valid_values = values;
}

/// Sets the default separator between the values of an argument.
pub fn setDefaultValuesDelimiter(self: *Arg) void {
    self.setValuesDelimiter(DEFAULT_VALUES_DELIMITER);
}

/// Sets separator between the values of an argument.
pub fn setValuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
}

/// Sets the index of a positional argument starting with **1**.
/// It is optional so by default it will be assigned based on order of defining argument.
///
/// Note: Setting index for options will not take any effect and it will be sliently ignored.
pub fn setIndex(self: *Arg, index: usize) void {
    self.index = index;
}

pub fn addProperty(self: *Arg, property: Property) void {
    return self.properties.insert(property);
}

pub fn removeProperty(self: *Arg, property: Property) void {
    return self.properties.remove(property);
}

// # Getters

pub fn hasProperty(self: *const Arg, property: Property) bool {
    return self.properties.contains(property);
}

pub fn isValidValue(self: *const Arg, value_to_check: []const u8) bool {
    if (self.valid_values) |values| {
        for (values) |value| {
            if (std.mem.eql(u8, value, value_to_check)) return true;
        }
        return false;
    }
    return true;
}
