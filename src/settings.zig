const std = @import("std");

pub fn MakeSettings(comptime AnonOption: type) type {
    if (@typeInfo(AnonOption) != .Enum)
        @compileError(
            @src().fn_name ++ " expected `AnonOption` to be enum, found " ++ @typeName(AnonOption),
        );

    return struct {
        const Self = @This();
        pub const Option = AnonOption;
        options: std.EnumMap(Option, bool) = .{},

        pub fn apply(self: *Self, option: Option) void {
            return self.options.put(option, true);
        }

        pub fn remove(self: *Self, option: Option) void {
            return self.options.remove(option);
        }

        pub fn isApplied(self: *const Self, option: Option) bool {
            return self.options.contains(option);
        }
    };
}

test "settings generator" {
    const CmdSettings = MakeSettings(struct {
        /// will doc comment visible?
        takes_value: bool,
        subcommand_required: bool,
    });
    var settings = CmdSettings{};

    try std.testing.expectEqual(false, settings.isApplied(.takes_value));
    settings.apply(.takes_value);
    try std.testing.expectEqual(true, settings.isApplied(.takes_value));
}
