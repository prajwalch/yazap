const ArgvIterator = @This();
const std = @import("std");

argv: []const [:0]const u8,
next_index: usize,
current_index: usize,

pub fn init(argv: []const [:0]const u8) ArgvIterator {
    return ArgvIterator{
        .argv = argv,
        .next_index = 0,
        .current_index = 0,
    };
}

pub fn next(self: *ArgvIterator) ?[:0]const u8 {
    if (self.next_index >= self.argv.len) return null;

    self.current_index = self.next_index;
    self.next_index += 1;

    return self.argv[self.current_index];
}

pub fn nextValue(self: *ArgvIterator) ?[:0]const u8 {
    const provided_value = self.next() orelse return null;
    if (std.mem.startsWith(u8, provided_value, "--")) return null;
    return provided_value;
}

pub fn rest(self: *ArgvIterator) ?[]const [:0]const u8 {
    if (self.next_index >= self.argv.len) return null;

    const rest_of_argv = self.argv[self.next_index..];
    self.next_index = self.argv.len;
    return rest_of_argv;
}
