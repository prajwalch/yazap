const Command = @This();

const std = @import("std");
const Parser = @import("parser/Parser.zig");
const Arg = @import("Arg.zig");
const ArgsContext = @import("parser/ArgsContext.zig");
const Tokenizer = @import("parser/tokenizer.zig").Tokenizer;

const mem = std.mem;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const Setting = struct {
    takes_value: bool,
    arg_required: bool,
    subcommand_required: bool,

    pub fn initDefault() Setting {
        return Setting{
            .takes_value = false,
            .arg_required = false,
            .subcommand_required = false,
        };
    }
};

pub const Error = error{
    InvalidCmdLine,
    Overflow,
} || Parser.Error;

allocator: Allocator,
name: []const u8,
about: ?[]const u8,
args: ArrayList(Arg),
subcommands: ArrayList(Command),
process_args: ?[]const [:0]u8,
setting: Setting,

pub fn new(allocator: Allocator, name: []const u8) Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .about = null,
        .args = ArrayList(Arg).init(allocator),
        .subcommands = ArrayList(Command).init(allocator),
        .process_args = null,
        .setting = Setting.initDefault(),
    };
}

pub fn newWithHelpTxt(allocator: Allocator, name: []const u8, about: []const u8) Command {
    var self = Command.new(allocator, name);
    self.about = about;
    return self;
}

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

pub fn addArg(self: *Command, new_arg: Arg) !void {
    return self.args.append(new_arg);
}

pub fn addSubcommand(self: *Command, new_subcommand: Command) !void {
    return self.subcommands.append(new_subcommand);
}

pub fn takesSingleValue(self: *Command, arg_name: []const u8) !void {
    try self.takesNValues(arg_name, 1);
}

pub fn takesNValues(self: *Command, arg_name: []const u8, n: usize) !void {
    var arg = Arg.new(arg_name);
    arg.minValues(1);
    arg.maxValues(n);
    if (n > 1) arg.valuesDelimiter(",");

    try self.addArg(arg);
    self.setting.takes_value = true;
}

pub fn argRequired(self: *Command, boolean: bool) void {
    self.setting.arg_required = boolean;
}

pub fn subcommandRequired(self: *Command, boolean: bool) void {
    self.setting.subcommand_required = boolean;
}

pub fn countArgs(self: *const Command) usize {
    return (self.args.items.len);
}

pub fn countSubcommands(self: *const Command) usize {
    return (self.subcommands.items.len);
}

pub fn findArgByShortName(self: *const Command, short_name: u8) ?*const Arg {
    for (self.args.items) |*arg| {
        if (arg.short_name) |s| {
            if (s == short_name) return arg;
        }
    }
    return null;
}

pub fn findArgByLongName(self: *const Command, long_name: []const u8) ?*const Arg {
    for (self.args.items) |*arg| {
        if (arg.long_name) |l| {
            if (mem.eql(u8, l, long_name)) return arg;
        }
    }
    return null;
}

pub fn parseProcess(self: *Command) Error!ArgsContext {
    self.process_args = try std.process.argsAlloc(self.allocator);
    return self.parseFrom(self.process_args.?[1..]);
}

pub fn parseFrom(self: *Command, argv: []const [:0]const u8) Parser.Error!ArgsContext {
    var parser = Parser.init(self.allocator, Tokenizer.init(argv), self);
    return parser.parse();
}
