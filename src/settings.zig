const std = @import("std");
const EnumField = std.builtin.TypeInfo.EnumField;

pub fn MakeSettings(comptime options_name: []const []const u8) type {
    return struct {
        const Self = @This();
        pub const Options = MakeOptions(options_name);

        options: std.EnumMap(Options, bool) = .{},

        pub fn apply(self: *Self, opt: Options) void {
            return self.options.put(opt, true);
        }

        pub fn remove(self: *Self, opt: Options) void {
            return self.options.remove(opt);
        }

        pub fn isApplied(self: *const Self, opt: Options) bool {
            return self.options.contains(opt);
        }
    };
}

fn MakeOptions(comptime options_name: []const []const u8) type {
    var fields: []const EnumField = &[_]EnumField{};
    for (options_name) |option_name, idx| {
        fields = fields ++ &[_]EnumField{
            .{ .name = option_name, .value = idx },
        };
    }
    return @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = u8,
            .fields = fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

test "settings generator" {
    const CmdSettings = MakeSettings(&[_][]const u8{
        "takes_value",
        "subcommand_required",
    });

    var settings = CmdSettings{};

    try std.testing.expectEqual(false, settings.isApplied(.takes_value));
    settings.apply(.takes_value);
    try std.testing.expectEqual(true, settings.isApplied(.takes_value));
}
