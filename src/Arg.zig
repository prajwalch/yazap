const Arg = @This();
const std = @import("std");

const Settings = struct {
    all_values_required: bool,

    pub fn initDefault() Settings {
        return Settings{
            .all_values_required = false,
        };
    }
};

name: []const u8,
min_values: usize = 0,
max_values: usize = 0,
allowed_values: ?[]const []const u8,
settings: Settings,

pub fn new(name: []const u8) Arg {
    return Arg{
        .name = name,
        .allowed_values = null,
        .settings = Settings.initDefault(),
    };
}

pub fn minValues(self: *Arg, num: usize) void {
    self.min_values = num;
}

pub fn maxValues(self: *Arg, num: usize) void {
    self.max_values = num;
}

pub fn allowedValues(self: *Arg, values: []const []const u8) void {
    self.allowed_values = values;
}

pub fn allValuesRequired(self: *Arg, boolean: bool) void {
    self.settings.all_values_required = boolean;
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
