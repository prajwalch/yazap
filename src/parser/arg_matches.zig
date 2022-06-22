const std = @import("std");
const MatchedArg = @import("MatchedArg.zig");

const ArgValue = MatchedArg.Value;
const ArgHashMap = std.StringHashMap(ArgValue);

pub const ArgMatches = struct {
    allocator: std.mem.Allocator,
    args: ArgHashMap,
    subcommand: ?*SubCommand,

    pub fn init(allocator: std.mem.Allocator) ArgMatches {
        return ArgMatches{
            .allocator = allocator,
            .args = ArgHashMap.init(allocator),
            .subcommand = null,
        };
    }

    pub fn deinit(self: *ArgMatches) void {
        var args_value_iter = self.args.valueIterator();

        while (args_value_iter.next()) |value| {
            switch (value.*) {
                .many => |v| v.deinit(),
                else => {},
            }
        }
        self.args.deinit();

        if (self.subcommand) |subcommand| {
            subcommand.deinit();
            self.allocator.destroy(subcommand);
        }
    }

    pub fn putMatchedArg(self: *ArgMatches, arg: MatchedArg) !void {
        return self.args.put(arg.name, arg.value);
    }

    pub fn setSubcommand(self: *ArgMatches, subcommand: SubCommand) !void {
        var alloc_subcmd = try self.allocator.create(SubCommand);
        alloc_subcmd.* = subcommand;
        self.subcommand = alloc_subcmd;
    }

    pub fn isPresent(self: *const ArgMatches, name_to_lookup: []const u8) bool {
        if (self.args.contains(name_to_lookup)) {
            return true;
        } else if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, name_to_lookup))
                return true;
        }

        return false;
    }

    pub fn valueOf(self: *const ArgMatches, arg_name: []const u8) ?[]const u8 {
        if (self.args.get(arg_name)) |value| {
            switch (value) {
                .single => |val| return val,
                else => return null,
            }
        } else if (self.subcommand) |subcmd| {
            if (subcmd.matches) |matches| {
                return matches.valueOf(arg_name);
            }
        }

        return null;
    }

    pub fn valuesOf(self: *ArgMatches, name_to_lookup: []const u8) ?[][]const u8 {
        if (self.args.get(name_to_lookup)) |value| {
            switch (value) {
                .many => |*v| return v.items[0..],
                else => return null,
            }
        } else {
            return null;
        }
    }

    pub fn subcommandMatches(self: *const ArgMatches, subcmd_name: []const u8) ?ArgMatches {
        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
                return subcmd.matches;
            }
        }
        return null;
    }
};

pub const SubCommand = struct {
    name: []const u8,
    matches: ?ArgMatches,

    pub fn initWithoutArg(name: []const u8) SubCommand {
        return SubCommand{
            .name = name,
            .matches = null,
        };
    }

    pub fn initWithArg(name: []const u8, arg_matches: ArgMatches) SubCommand {
        var self = initWithoutArg(name);
        self.matches = arg_matches;
        return self;
    }

    pub fn deinit(self: *SubCommand) void {
        if (self.matches) |*matches| matches.deinit();
    }
};
