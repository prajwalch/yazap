const Command = @This();

const std = @import("std");
const Parser = @import("Parser.zig");
const Arg = @import("Arg.zig");
const ArgMatches = @import("arg_matches.zig").ArgMatches;

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

allocator: Allocator,
name: []const u8,
about: ?[]const u8,
args: ArrayList(Arg),
subcommands: ArrayList(Command),
setting: Setting,

pub fn new(allocator: Allocator, name: []const u8) Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .about = null,
        .args = ArrayList(Arg).init(allocator),
        .subcommands = ArrayList(Command).init(allocator),
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

pub fn parseProcess(self: *Command) Parser.Error!ArgMatches {
    const process_args = try std.process.argsAlloc(self.allocator);
    defer std.process.argsFree(self.allocator, process_args);
    errdefer std.process.argsFree(self.allocator, process_args);

    if (process_args.len > 1) {
        return self.parseFrom(process_args[1..]);
    } else {
        return self.parseFrom(&[_][:0]const u8{});
    }
}

pub fn parseFrom(self: *Command, argv: []const [:0]const u8) Parser.Error!ArgMatches {
    var parser = Parser.init(self.allocator, argv, self);
    return parser.parse();
}
