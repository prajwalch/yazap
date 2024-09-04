const ShortOptionIterator = @This();

/// Buffer containing all options.
options: []const u8,
/// Value of all options.
attached_value: ?[]const u8 = null,
/// Buffer index where the next option is.
cursor: usize = 0,

/// Creates an iterator for the given options.
pub fn init(options: []const u8, attached_value: ?[]const u8) ShortOptionIterator {
    return ShortOptionIterator{
        .options = options,
        .attached_value = attached_value,
    };
}

/// Returns the next option or returns `null` if iteration is ended.
pub fn next(self: *ShortOptionIterator) ?u8 {
    if (self.isAtEnd()) return null;
    defer self.cursor += 1;

    return self.options[self.cursor];
}

/// Returns the value of current option or return `null` if it's not available.
pub fn getOptionValue(self: *ShortOptionIterator) ?[]const u8 {
    return self.attached_value;
}

/// Returns the remaining options.
pub fn getRemainingOptions(self: *ShortOptionIterator) ?[]const u8 {
    if (self.isAtEnd()) return null;
    defer self.cursor = self.options.len;

    return self.options[self.cursor..];
}

/// Returns the current option as a string.
pub fn getCurrentOptionAsStr(self: *ShortOptionIterator) []const u8 {
    return self.options[self.cursor - 1 .. self.cursor];
}

/// Returns `true` if current option contains value; otherwise `false`.
pub fn optionContainsValue(self: *ShortOptionIterator) bool {
    return ((self.attached_value != null) and (self.attached_value.?.len >= 0));
}

/// Checks if the iterator has remainig options left to be iterate.
pub fn hasOptionsLeft(self: *ShortOptionIterator) bool {
    return self.cursor < self.options.len;
}

/// Returns `true` if iteration is ended.
fn isAtEnd(self: *ShortOptionIterator) bool {
    return (self.cursor >= self.options.len);
}
