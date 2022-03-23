const std = @import("std");
const MatchedFlag = @import("MatchedFlag.zig");

const FlagArg = MatchedFlag.Arg;
const FlagHashMap = std.StringHashMap(FlagArg);

pub const ArgMatches = struct {
    allocator: std.mem.Allocator,

    // TODO: Add support for multiple values.
    // Ex: cmd arg1 arg2 where arg1 and arg2 are value
    value: ?[]const u8,
    flags: FlagHashMap,
    subcommand: ?*SubCommand,

    pub fn init(allocator: std.mem.Allocator) ArgMatches {
        return ArgMatches{
            .allocator = allocator,
            .value = null,
            .flags = FlagHashMap.init(allocator),
            .subcommand = null,
        };
    }

    pub fn deinit(self: *ArgMatches) void {
        self.flags.deinit();
        if (self.subcommand) |subcommand| {
            subcommand.deinit();
            self.allocator.destroy(subcommand);
        }
    }

    pub fn putFlag(self: *ArgMatches, flag: MatchedFlag) !void {
        return self.flags.put(flag.name, flag.arg);
    }

    pub fn setSubcommand(self: *ArgMatches, subcommand: SubCommand) !void {
        var alloc_subcmd = try self.allocator.create(SubCommand);
        alloc_subcmd.* = subcommand;
        self.subcommand = alloc_subcmd;
    }

    pub fn setValue(self: *ArgMatches, value: []const u8) void {
        self.value = value;
    }

    pub fn isPresent(self: *const ArgMatches, name_to_lookup: []const u8) bool {
        if (self.flags.contains(name_to_lookup)) {
            return true;
        }

        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, name_to_lookup))
                return true;
        }

        return false;
    }

    pub fn valueOf(self: *const ArgMatches, arg_name: []const u8) ?[]const u8 {
        const flag_arg = self.flags.get(arg_name);

        if (flag_arg) |arg| {
            switch (arg) {
                .single => |val| return val,
                else => return null,
            }
        }

        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, arg_name)) {
                if (subcmd.matches) |matches| {
                    return matches.value;
                }
            }
        }

        return null;
    }

    pub fn getValue(self: *const ArgMatches) ?[]const u8 {
        return self.value;
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
