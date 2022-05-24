const std = @import("std");
const Arg = @import("Arg.zig");

pub fn boolean(name: []const u8, short_name: ?u8) Arg {
    var arg = Arg.new(name);
    arg.setLongNameSameAsName();
    if (short_name) |n| arg.shortName(n);

    return arg;
}

pub fn argOne(name: []const u8, short_name: ?u8) Arg {
    return argN(name, short_name, 1);
}

pub fn argN(name: []const u8, short_name: ?u8, max_values: usize) Arg {
    var arg = Arg.new(name);
    arg.minValues(1);
    arg.maxValues(max_values);
    arg.setLongNameSameAsName();

    if (short_name) |n| arg.shortName(n);
    if (max_values > 1) arg.valuesDelimiter(",");

    return arg;
}

pub fn option(name: []const u8, short_name: ?u8, options: []const []const u8) Arg {
    var arg = argN(name, short_name, 1);
    arg.allowedValues(options);
    return arg;
}
