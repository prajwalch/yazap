const std = @import("std");
pub const err = @import("error.zig");
pub const App = @import("App.zig");
pub const Arg = @import("Arg.zig");
pub const ArgsContext = @import("args_context.zig").ArgsContext;
pub const Command = @import("Command.zig");

test "emit docs" {
    std.testing.refAllDeclsRecursive(@This());
}
