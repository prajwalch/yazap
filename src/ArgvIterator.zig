const ArgvIterator = @This();
const std = @import("std");

const mem = std.mem;
const testing = std.testing;

pub const RawArg = struct {
    name: []const u8,

    pub fn init(name: []const u8) RawArg {
        return RawArg{ .name = name };
    }

    pub fn isShort(self: *RawArg) bool {
        return (mem.startsWith(u8, self.name, "-") and mem.count(u8, self.name, "-") == 1);
    }

    pub fn isLong(self: *RawArg) bool {
        return (mem.startsWith(u8, self.name, "--"));
    }

    pub fn toShort(self: *RawArg) ?ShortFlags {
        const trimmed_name = mem.trim(u8, self.name, "-");

        if (trimmed_name.len == 0) {
            return null;
        } else {
            return ShortFlags.init(trimmed_name);
        }
    }

    pub fn toLong(self: *RawArg) ?LongFlag {
        const trimmed_name = mem.trim(u8, self.name, "--");

        if (trimmed_name.len == 0)
            return null;

        // Extract value if passed as like '--flag=value'
        if (mem.indexOfScalar(u8, trimmed_name, '=')) |delimiter_pos| {
            const flag_name = trimmed_name[0..delimiter_pos];
            const flag_value = trimmed_name[delimiter_pos + 1 ..];

            if (flag_value.len == 0) {
                return LongFlag.init(flag_name, null);
            } else {
                return LongFlag.init(flag_name, flag_value);
            }
        } else {
            return LongFlag.init(trimmed_name, null);
        }
    }
};

pub const ShortFlags = struct {
    name: []const u8,
    /// Any value after the '=' sign
    fixed_value: ?[]const u8,
    /// Will be use to iterate chained flags (if have)
    /// or to consume rest of the values
    next_index: usize,
    current_index: usize,

    pub fn init(name: []const u8) ShortFlags {
        var self = ShortFlags{
            .name = name,
            .fixed_value = null,
            .next_index = 0,
            .current_index = 0,
        };

        self.checkAndSetFixedValue();
        return self;
    }

    fn checkAndSetFixedValue(self: *ShortFlags) void {
        if (self.name.len >= 2 and self.name[1] == '=') {
            self.fixed_value = self.name[2..];
            self.name = self.name[0..1];
        }
    }

    pub fn nextFlag(self: *ShortFlags) ?u8 {
        if (self.next_index >= self.name.len) return null;

        defer self.next_index += 1;

        self.current_index = self.next_index;
        return self.name[self.current_index];
    }

    /// Return remaining items as value
    pub fn nextValue(self: *ShortFlags) ?[]const u8 {
        if (self.fixed_value) |v| return v;
        if (self.next_index >= self.name.len) return null;

        defer self.next_index = self.name.len;

        return self.name[self.next_index..];
    }

    pub fn rollbackValue(self: *ShortFlags) void {
        if ((self.current_index + 1) >= self.name.len) {
            self.next_index = self.current_index;
        } else {
            self.next_index = self.current_index + 1;
        }
    }
};

pub const LongFlag = struct {
    name: []const u8,
    value: ?[]const u8,

    pub fn init(name: []const u8, value: ?[]const u8) LongFlag {
        return LongFlag{ .name = name, .value = value };
    }
};

argv: []const [:0]const u8,
current_index: usize,

pub fn init(argv: []const [:0]const u8) ArgvIterator {
    return ArgvIterator{
        .argv = argv,
        .current_index = 0,
    };
}

pub fn next(self: *ArgvIterator) ?RawArg {
    defer self.current_index += 1;

    if (self.current_index >= self.argv.len) return null;
    const value = @as([]const u8, self.argv[self.current_index]);
    return RawArg.init(value);
}

pub fn nextValue(self: *ArgvIterator) ?[]const u8 {
    var next_value = self.next() orelse return null;

    if (next_value.isShort() or next_value.isLong()) {
        // Rollback value to prevent it from skipping while parsing
        self.current_index -= 1;
        return null;
    } else {
        return next_value.name;
    }
}

pub fn rest(self: *ArgvIterator) ?[]const [:0]const u8 {
    defer self.current_index = self.argv.len;

    if (self.current_index >= self.argv.len) return null;
    return self.argv[self.current_index..];
}

test "ArgvIterator" {
    const argv: []const [:0]const u8 = &.{
        "cmd",
        "--long-bool-flag",
        "--long-arg-flag=value1",
        "--long-arg-flag2",
        "value2",
        "-a",
        "-b=value3",
        "-cvalue4",
        "-d",
        "value5",
        "-abcd",
    };

    var iter = ArgvIterator.init(argv);
    try testing.expectEqualStrings("cmd", iter.nextValue().?);

    var arg1 = iter.next().?;
    try testing.expectEqual(true, arg1.isLong());

    var arg2 = iter.next().?;
    try testing.expectEqual(true, arg2.isLong());

    var arg2_long = arg2.toLong().?;
    try testing.expectEqualStrings("long-arg-flag", arg2_long.name);
    try testing.expectEqualStrings("value1", arg2_long.value.?);

    var arg3 = iter.next().?;
    try testing.expectEqual(true, arg3.isLong());

    var arg3_long = arg3.toLong().?;
    try testing.expectEqualStrings("long-arg-flag2", arg3_long.name);
    try testing.expect(arg3_long.value == null);
    try testing.expectEqualStrings("value2", iter.nextValue().?);

    var arg4 = iter.next().?;
    try testing.expectEqual(true, arg4.isShort());

    var arg5 = iter.next().?;
    try testing.expectEqual(true, arg5.isShort());

    var arg5_short = arg5.toShort().?;
    try testing.expect('b' == arg5_short.nextFlag().?);
    try testing.expectEqualStrings("value3", arg5_short.nextValue().?);

    var arg6 = iter.next().?;
    try testing.expectEqual(true, arg6.isShort());

    var arg6_short = arg6.toShort().?;
    try testing.expect('c' == arg6_short.nextFlag().?);
    try testing.expectEqualStrings("value4", arg6_short.nextValue().?);

    var arg7 = iter.next().?;
    try testing.expectEqual(true, arg7.isShort());

    var arg7_short = arg7.toShort().?;
    try testing.expect('d' == arg7_short.nextFlag().?);
    try testing.expect(null == arg7_short.nextValue());
    try testing.expectEqualStrings("value5", iter.nextValue().?);

    var arg8 = iter.next().?;
    try testing.expectEqual(true, arg8.isShort());

    var arg8_short = arg8.toShort().?;
    try testing.expect('a' == arg8_short.nextFlag().?);
    try testing.expect('b' == arg8_short.nextFlag().?);
    try testing.expect('c' == arg8_short.nextFlag().?);
    try testing.expect('d' == arg8_short.nextFlag().?);
}

test "ShortFlags" {
    const ex_flag = "fvalue";
    var short_flag = ShortFlags.init(ex_flag);

    try testing.expect(short_flag.nextFlag().? == 'f');
    try testing.expectEqualStrings("value", short_flag.nextValue().?);
    try testing.expect(short_flag.nextValue() == null);

    short_flag.rollbackValue();
    try testing.expectEqualStrings("value", short_flag.nextValue().?);
}
