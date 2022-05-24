const Arg = @This();
const std = @import("std");

const Settings = struct {
    takes_value: bool,
    allow_empty_value: bool,

    pub fn initDefault() Settings {
        return Settings{
            .takes_value = false,
            .allow_empty_value = false,
        };
    }
};

name: []const u8,
short_name: ?u8,
long_name: ?[]const u8,
min_values: ?usize = null,
max_values: ?usize = null,
allowed_values: ?[]const []const u8,
values_delimiter: ?[]const u8,
settings: Settings,

pub fn new(name: []const u8) Arg {
    return Arg{
        .name = name,
        .short_name = null,
        .long_name = null,
        .allowed_values = null,
        .values_delimiter = null,
        .settings = Settings.initDefault(),
    };
}

pub fn shortName(self: *Arg, short_name: u8) void {
    self.short_name = short_name;
}

pub fn setShortNameFromName(self: *Arg) void {
    self.shortName(self.name[0]);
}

pub fn longName(self: *Arg, long_name: []const u8) void {
    self.long_name = long_name;
}

pub fn setLongNameSameAsName(self: *Arg) void {
    self.longName(self.name);
}

pub fn minValues(self: *Arg, num: usize) void {
    self.min_values = num;
    self.takesValue(true);
}

pub fn maxValues(self: *Arg, num: usize) void {
    self.max_values = num;
    self.takesValue(true);
}

pub fn allowedValues(self: *Arg, values: []const []const u8) void {
    self.allowed_values = values;
    self.takesValue(true);
}

pub fn valuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
    self.takesValue(true);
}

pub fn takesValue(self: *Arg, b: bool) void {
    self.settings.takes_value = b;
}

pub fn allowedEmptyValue(self: *Arg, b: bool) void {
    self.settings.allow_empty_value = b;
}

pub fn verifyValueInAllowedValues(self: *const Arg, value_to_check: []const u8) bool {
    if (self.allowed_values) |values| {
        for (values) |value| {
            if (std.mem.eql(u8, value, value_to_check)) return true;
        }
        return false;
    } else {
        return true;
    }
}

// min 1 -> 5
pub fn remainingValuesToConsume(self: *const Arg, num_consumed_values: usize) usize {
    const num_required_values = blk: {
        if (self.max_values) |n| {
            break :blk n;
        } else if (self.min_values) |n| {
            break :blk n;
        } else {
            break :blk 0;
        }
    };

    if (num_consumed_values > num_required_values) {
        return 0;
    } else {
        return num_required_values - num_consumed_values;
    }
}
