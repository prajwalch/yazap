const Command = @This();

const std = @import("std");
const Parser = @import("parser/Parser.zig");
const Arg = @import("Arg.zig");
const ArgsContext = @import("parser/ArgsContext.zig");
const Tokenizer = @import("parser/tokenizer.zig").Tokenizer;
const PrintError = @import("parser/ErrorBuilder.zig").PrintError;

const mem = std.mem;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const Setting = struct {
    takes_value: bool = false,
    arg_required: bool = false,
    subcommand_required: bool = false,
};

pub const Error = error{
    InvalidCmdLine,
    Overflow,
} || Parser.Error || PrintError;

allocator: Allocator,
name: []const u8,
about: ?[]const u8,
args: ArrayList(Arg),
subcommands: ArrayList(Command),
process_args: ?[]const [:0]u8,
setting: Setting,

/// Creates a new instance of it
pub fn new(allocator: Allocator, name: []const u8) Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .about = null,
        .args = ArrayList(Arg).init(allocator),
        .subcommands = ArrayList(Command).init(allocator),
        .process_args = null,
        .setting = Setting{},
    };
}

pub fn newWithHelpTxt(allocator: Allocator, name: []const u8, about: []const u8) Command {
    var self = Command.new(allocator, name);
    self.about = about;
    return self;
}

/// Release all allocated memory
pub fn deinit(self: *Command) void {
    self.args.deinit();

    for (self.subcommands.items) |*subcommand| {
        subcommand.deinit();
    }
    self.subcommands.deinit();

    if (self.process_args) |args| {
        std.process.argsFree(self.allocator, args);
    }
}

/// Appends the new arg into the args list
pub fn addArg(self: *Command, new_arg: Arg) !void {
    return self.args.append(new_arg);
}

/// Appends the new subcommand into the subcommands list
pub fn addSubcommand(self: *Command, new_subcommand: Command) !void {
    return self.subcommands.append(new_subcommand);
}

/// Create a new [Argument](/#root;Arg) with the given name and specifies that Command will take single value
pub fn takesSingleValue(self: *Command, arg_name: []const u8) !void {
    try self.takesNValues(arg_name, 1);
}

/// Creates an [Argument](/#root;Arg) with given name and specifies that command will take `n` values
pub fn takesNValues(self: *Command, arg_name: []const u8, n: usize) !void {
    var arg = Arg.new(arg_name);
    arg.minValues(1);
    arg.maxValues(n);
    if (n > 1) arg.valuesDelimiter(",");

    try self.addArg(arg);
    self.takesValue(true);
}

/// Specifies that the command takes value. Default to 'false`
pub fn takesValue(self: *Command, b: bool) void {
    self.setting.takes_value = b;
}

/// Specifies that argument is required to provide. Default to `false`
pub fn argRequired(self: *Command, boolean: bool) void {
    self.setting.arg_required = boolean;
}

/// Specifies that sub-command is required to provide. Default to `false`
pub fn subcommandRequired(self: *Command, boolean: bool) void {
    self.setting.subcommand_required = boolean;
}

pub fn countArgs(self: *const Command) usize {
    return (self.args.items.len);
}

pub fn countSubcommands(self: *const Command) usize {
    return (self.subcommands.items.len);
}

/// Linearly searches for an argument with short name equals to given `short_name`.
/// Returns a const pointer of a found argument otherwise null.
pub fn findArgByShortName(self: *const Command, short_name: u8) ?*const Arg {
    for (self.args.items) |*arg| {
        if (arg.short_name) |s| {
            if (s == short_name) return arg;
        }
    }
    return null;
}

/// Linearly searches for an argument with long name equals to given `long_name`.
/// Returns a const pointer of a found argument otherwise null.
pub fn findArgByLongName(self: *const Command, long_name: []const u8) ?*const Arg {
    for (self.args.items) |*arg| {
        if (arg.long_name) |l| {
            if (mem.eql(u8, l, long_name)) return arg;
        }
    }
    return null;
}

/// Linearly searches a sub-command with name equals to given `subcmd_name`.
/// Returns a const pointer of a found sub-command otherwise null.
pub fn findSubcommand(self: *const Command, provided_subcmd: []const u8) ?*const Command {
    for (self.subcommands.items) |*subcmd| {
        if (std.mem.eql(u8, subcmd.name, provided_subcmd)) {
            return subcmd;
        }
    }

    return null;
}

/// Starts parsing the process arguments
pub fn parseProcess(self: *Command) Error!ArgsContext {
    self.process_args = try std.process.argsAlloc(self.allocator);
    return self.parseFrom(self.process_args.?[1..]);
}

/// Starts parsing the given arguments
pub fn parseFrom(self: *Command, argv: []const [:0]const u8) Error!ArgsContext {
    var parser = Parser.init(self.allocator, Tokenizer.init(argv), self);
    const args_ctx = parser.parse() catch |e| {
        try parser.err_builder.logError();
        return e;
    };
    return args_ctx;
}

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
