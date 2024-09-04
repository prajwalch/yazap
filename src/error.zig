/// An error type returned by the standard allocator.
pub const AllocatorError = @import("std").mem.Allocator.Error;

const parse_error = @import("./parser/parse_error.zig");
pub const ParseError = parse_error.ParseError;
pub const PrintError = parse_error.PrintError;
/// An Error returned by the `std.process.argsAlloc`.
///
/// `std.process.argsAlloc` is used to obtain the command line arguments from
/// the current process.
pub const OtherError = error{Overflow};
/// Complete error type of the library.
pub const YazapError = AllocatorError || ParseError || PrintError || OtherError;
