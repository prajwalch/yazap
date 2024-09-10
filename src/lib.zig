const std = @import("std");
pub const App = @import("App.zig");
pub const Arg = @import("Arg.zig");
pub const ArgMatches = @import("ArgMatches.zig");
pub const Command = @import("Command.zig");
pub const yazap_error = @import("error.zig");
pub const YazapError = yazap_error.YazapError;

test "emit docs" {
    comptime {
        std.testing.refAllDecls(App);
        std.testing.refAllDecls(Arg);
        std.testing.refAllDecls(ArgMatches);
        std.testing.refAllDecls(Command);
        std.testing.refAllDecls(yazap_error);
    }
}
