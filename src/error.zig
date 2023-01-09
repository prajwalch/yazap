const std = @import("std");
const Arg = @import("Arg.zig");

// zig fmt: off
pub const YazapError = error{ InvalidCmdLine, Overflow }
    || ParseError
    || AllocatorError
    || WriteError;
// zig fmt: on
pub const AllocatorError = std.mem.Allocator.Error;
pub const WriteError = std.os.WriteError;
pub const ParseError = error{
    UnknownFlag,
    UnknownCommand,
    CommandArgumentNotProvided,
    CommandSubcommandNotProvided,
    FlagValueNotProvided,
    UnneededAttachedValue,
    EmptyFlagValueNotAllowed,
    ProvidedValueIsNotValidOption,
    TooFewArgValue,
    TooManyArgValue,
};

pub const Context = std.EnumMap(ContextKind, ContextValueKind);
pub const ContextKind = enum {
    invalid_arg,
    invalid_value,
    valid_cmd,
    valid_arg,
    valid_values,
    min_num_values,
    max_num_values,
};
pub const ContextValueKind = union(enum) {
    single: []const u8,
    many: []const []const u8,
};

pub const Error = struct {
    context: Context,

    pub fn init() Error {
        return Error{ .context = .{} };
    }

    pub fn setContext(self: *Error, anon_ctx: anytype) void {
        self.constructAndPutContext(anon_ctx);
    }

    pub fn getValue(self: *Error, ctx_kind: ContextKind) []const u8 {
        return self.context.getAssertContains(ctx_kind).single;
    }

    pub fn getValues(self: *Error, ctx_kind: ContextKind) []const []const u8 {
        return self.context.getAssertContains(ctx_kind).many;
    }

    pub fn log(self: *Error, err_set: YazapError) YazapError!void {
        // TODO: currently, using `std.io.bufferedWriter` gives
        // `buffered_writer.zig:9:37: error: container 'std.fs.file.File' has no member called 'Error'`
        //
        // once that will be fixed use `bufferedWriter` here
        const writer = std.io.getStdErr().writer();

        switch (err_set) {
            AllocatorError.OutOfMemory => try writer.print("error: Unable to allocate memory\n", .{}),

            ParseError.UnknownFlag => try writer.print("Unknown flag '{s}'\n", .{self.getValue(.invalid_arg)}),
            ParseError.UnknownCommand => try writer.print("Unknown Command '{s}'\n", .{self.getValue(.invalid_arg)}),
            ParseError.CommandArgumentNotProvided => {
                try writer.print("The command '{s}' requires a value but none is provided\n", .{self.getValue(.valid_cmd)});
            },
            ParseError.CommandSubcommandNotProvided => {
                try writer.print("The command '{s}' requires a subcommand but none is provided", .{self.getValue(.valid_cmd)});
            },
            ParseError.FlagValueNotProvided => try writer.print("The flag '{s}' takes a value but none is provided\n", .{self.getValue(.valid_arg)}),
            ParseError.UnneededAttachedValue => try writer.print("Arg '{s}' does not takes value but provided\n", .{self.getValue(.valid_arg)}),
            ParseError.EmptyFlagValueNotAllowed => try writer.print("The flag '{s}' does not allow to pass empty value\n", .{self.getValue(.valid_arg)}),
            ParseError.ProvidedValueIsNotValidOption => {
                try writer.print("Invalid value '{s}' for arg '{s}'\nValid options are:", .{
                    self.getValue(.invalid_value),
                    self.getValue(.valid_arg),
                });
                for (self.getValues(.valid_values)) |v|
                    try writer.print("{s}\n", .{v});
            },
            ParseError.TooFewArgValue => try writer.print("Too few values for Arg '{s}'\n Expected at least '{s}'\n", .{
                self.getValue(.valid_arg),
                self.getValue(.min_num_values),
            }),
            ParseError.TooManyArgValue => {
                try writer.print(
                    \\Too many values for arg '{s}'
                    \\
                    \\Expected number of values to be {s}
                , .{ self.getValue(.valid_arg), self.getValue(.max_num_values) });
            },
            else => |e| try writer.print("error: Probably some os error occured `{s}`", .{@errorName(e)}),
        }
    }

    // TODO: Remove this function once we eliminate that use of anonymous struct for context parameter
    fn constructAndPutContext(self: *Error, anon_ctx: anytype) void {
        inline for (std.meta.fields(@TypeOf(anon_ctx))) |field| {
            const value = @field(anon_ctx, field.name);
            const ctx_kind = @field(ContextKind, field.name);
            const val_kind = switch (comptime ctx_kind) {
                .valid_values => .{ .many = value },
                .min_num_values, .max_num_values => .{ .single = std.fmt.comptimePrint("{d}", .{value}) },
                else => .{ .single = value },
            };
            self.context.put(ctx_kind, val_kind);
        }
    }
};

test "Error" {
    var err = Error.init();
    err.setContext(.{ .min_num_values = @as(usize, 2) });

    try std.testing.expectEqualStrings("2", err.getValue(.min_num_values));
}
