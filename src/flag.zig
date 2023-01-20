//! A wrapper around `Arg` which provides simple APIs to quickly define the different kind of flags.

const std = @import("std");
const Arg = @import("Arg.zig");

/// Defines a boolean flag
pub fn boolean(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.new(name, description);
    arg.setLongNameSameAsName();

    if (short_name) |n| arg.setShortName(n);

    return arg;
}

/// Defines a single argument flag
pub fn argOne(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    return argN(name, short_name, 1, description);
}

/// Defines a single argument flag with given pre-defined values
pub fn option(
    name: []const u8,
    short_name: ?u8,
    options: []const []const u8,
    description: ?[]const u8,
) Arg {
    var arg = argN(name, short_name, 1, description);
    arg.setAllowedValues(options);
    return arg;
}

/// Defines a given `max_values` number of arguments flag
pub fn argN(
    name: []const u8,
    short_name: ?u8,
    max_values: usize,
    description: ?[]const u8,
) Arg {
    var arg = Arg.new(name, description);
    arg.setMinValues(1);
    arg.setMaxValues(max_values);
    arg.setLongNameSameAsName();

    if (short_name) |n| arg.setShortName(n);
    if (max_values > 1) arg.setDefaultValuesDelimiter();

    return arg;
}

test "emit functions docs" {
    std.testing.refAllDecls(@This());
}
