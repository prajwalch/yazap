const ArgvIterator = @This();
const std = @import("std");

pub const Value = struct {
    name: [:0]const u8,

    pub fn startsWithDoubleHyphen(self: *const Value) bool {
        return (std.mem.startsWith(u8, self.name, "--"));
    }

    pub fn arg(_: *const Value, argv_iterator: *ArgvIterator) ?[:0]const u8 {
        const provided_arg = argv_iterator.next();

        if (provided_arg) |a| {
            if (a.startsWithDoubleHyphen()) return null;
            return a.name;
        }
        return null;
    }
};

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

pub fn next(self: *ArgvIterator) ?Value {
    if (self.next_index >= self.argv.len) return null;

    self.current_index = self.next_index;
    self.next_index += 1;
    return Value{
        .name = self.argv[self.current_index],
    };
}

pub fn rest(self: *ArgvIterator) ?[]const [:0]const u8 {
    if (self.next_index >= self.argv.len) return null;
    return self.argv[self.next_index..];
}
