const std = @import("std");
pub const flag = @import("flag.zig");
pub const Arg = @import("Arg.zig");
pub const Command = @import("Command.zig");
pub const ArgsContext = @import("parser/ArgsContext.zig");
pub const Yazap = @import("Yazap.zig");

test "emit docs" {
    std.testing.refAllDecls(@This());
}
