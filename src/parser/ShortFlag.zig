const ShortFlag = @This();

name: []const u8,
value: ?[]const u8,
cursor: usize,

pub fn initFromToken(name: []const u8, value: ?[]const u8) ShortFlag {
    return ShortFlag{
        .name = name,
        .value = value,
        .cursor = 0,
    };
}

pub fn next(self: *ShortFlag) ?u8 {
    if (self.isAtEnd()) return null;
    defer self.cursor += 1;

    return self.name[self.cursor];
}

pub fn getValue(self: *ShortFlag) ?[]const u8 {
    return (self.value);
}

pub fn getRemainTail(self: *ShortFlag) ?[]const u8 {
    if (self.isAtEnd()) return null;
    defer self.cursor = self.name.len;

    return self.name[self.cursor..];
}

pub fn hasValue(self: *ShortFlag) bool {
    if (self.value) |v| {
        return (v.len >= 1);
    } else {
        return false;
    }
}

pub fn hasEmptyValue(self: *ShortFlag) bool {
    if (self.value) |v| {
        return (v.len == 0);
    } else {
        return false;
    }
}

pub fn hasTail(self: *ShortFlag) bool {
    return (self.value == null and self.name.len > 1);
}

fn isAtEnd(self: *ShortFlag) bool {
    return (self.cursor >= self.name.len);
}
