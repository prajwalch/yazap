const std = @import("std");
const Arg = @import("Arg.zig");

pub fn boolean(comptime name: []const u8) Arg {
    return Arg.new(name);
}

pub fn argOne(comptime name: []const u8) Arg {
    return argN(name, 1);
}

pub fn argN(comptime name: []const u8, max_values: usize) Arg {
    var arg = Arg.new(name);
    arg.minValues(1);
    arg.maxValues(max_values);
    arg.allValuesRequired(true);
    return arg;
}

pub fn option(comptime name: []const u8, options: []const []const u8) Arg {
    var arg = argN(name, 1);
    arg.allowedValues(options);
    return arg;
}
