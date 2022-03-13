const Flag = @This();
const std = @import("std");

name: []const u8,
required_arg: usize,
allowed_set: ?[]const []const u8,

pub fn Bool(comptime name: []const u8) Flag {
    return ArgN(name, 0);
}

pub fn ArgOne(comptime name: []const u8) Flag {
    return ArgN(name, 1);
}

pub fn ArgN(comptime name: []const u8, nums_arg: usize) Flag {
    return Flag{
        .name = name,
        .required_arg = nums_arg,
        .allowed_set = null,
    };
}

pub fn Option(comptime name: []const u8, sets: []const []const u8) Flag {
    return Flag{
        .name = name,
        .required_arg = 0,
        .allowed_set = sets,
    };
}

pub fn verifyArgInAllowedSet(self: *const Flag, arg: []const u8) bool {
    if (self.allowed_set) |set| {
        for (set) |s| {
            if (std.mem.eql(u8, s, arg)) return true;
        }
        return false;
    } else {
        return true;
    }
}
