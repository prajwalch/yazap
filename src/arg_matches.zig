const std = @import("std");
const MatchedFlag = @import("MatchedFlag.zig");

const FlagArg = MatchedFlag.Arg;
const FlagHashMap = std.StringHashMap(FlagArg);

pub const ArgMatches = struct {
    flags: FlagHashMap,
    subcommand: ?SubCommand,

    pub fn init(allocator: std.mem.Allocator) ArgMatches {
        return ArgMatches{
            .flags = FlagHashMap.init(allocator),
            .subcommand = null,
        };
    }

    pub fn deinit(self: *ArgMatches) void {
        self.flags.deinit();
        if (self.subcommand) |*subcommand| {
            subcommand.deinit();
        }
    }

    pub fn putFlag(self: *ArgMatches, flag: MatchedFlag) !void {
        return self.flags.put(flag.name, flag.arg);
    }

    pub fn setSubcommand(self: *ArgMatches, subcommand: SubCommand) !void {
        self.subcommand = subcommand;
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
        } else {
            return null;
        }
    }

    pub fn subcommandMatches(self: *const ArgMatches, subcmd_name: []const u8) ?ArgMatches {
        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
                return ArgMatches{
                    .flags = subcmd.flags,
                    .subcommand = null,
                };
            }
        }
        return null;
    }
};

pub const SubCommand = struct {
    name: []const u8,
    flags: FlagHashMap,

    pub fn initWithoutArg(name: []const u8) SubCommand {
        return SubCommand{
            .name = name,
            .flags = undefined,
        };
    }

    pub fn initWithArg(name: []const u8, arg_matches: ArgMatches) SubCommand {
        var self = initWithoutArg(name);
        self.flags = arg_matches.flags;
        return self;
    }

    pub fn deinit(self: *SubCommand) void {
        self.flags.deinit();
    }
};
