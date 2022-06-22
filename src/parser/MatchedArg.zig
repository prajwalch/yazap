const MatchedArg = @This();
const std = @import("std");

pub const Value = union(enum) {
    none,
    single: []const u8,
    many: std.ArrayList([]const u8),
};

name: []const u8,
value: Value,

fn init(name: []const u8) MatchedArg {
    return MatchedArg{
        .name = std.mem.trimLeft(u8, name, "--"),
        .value = undefined,
    };
}

pub fn initWithoutValue(name: []const u8) MatchedArg {
    var self = init(name);
    self.value = .{ .none = undefined };
    return self;
}

pub fn initWithSingleValue(name: []const u8, value: []const u8) MatchedArg {
    var self = init(name);
    self.value = .{ .single = value };
    return self;
}

pub fn initWithManyValues(name: []const u8, values: std.ArrayList([]const u8)) MatchedArg {
    var self = init(name);
    self.value = .{ .many = values };
    return self;
}
