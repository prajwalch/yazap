const std = @import("std");
pub const err = @import("error.zig");
pub const flag = @import("flag.zig");
pub const args_context = @import("args_context.zig");
pub const App = @import("App.zig");
pub const Arg = @import("Arg.zig");
pub const Command = @import("Command.zig");

test "emit docs" {
    std.testing.refAllDecls(@This());
}
