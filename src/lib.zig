const std = @import("std");
pub const App = @import("App.zig");
pub const Arg = @import("Arg.zig");
pub const arg_matches = @import("arg_matches.zig");
pub const ArgMatches = arg_matches.ArgMatches;
pub const Command = @import("Command.zig");
pub const YazapError = @import("error.zig").YazapError;

test "emit docs" {
    std.testing.refAllDeclsRecursive(@This());
}
