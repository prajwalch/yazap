const std = @import("std");
pub const App = @import("App.zig");
pub const Arg = @import("Arg.zig");
pub const arg_matches = @import("arg_matches.zig");
pub const ArgMatches = arg_matches.ArgMatches;
pub const Command = @import("Command.zig");
pub const yazap_error = @import("error.zig");
pub const YazapError = yazap_error.YazapError;

test "emit docs" {
    comptime {
        std.testing.refAllDecls(App);
        std.testing.refAllDecls(Arg);
        std.testing.refAllDecls(arg_matches);
        std.testing.refAllDecls(Command);
        std.testing.refAllDecls(yazap_error);
    }
}
