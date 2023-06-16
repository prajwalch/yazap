const std = @import("std");
const Arg = @import("Arg.zig");
const Help = @import("help.zig").Help;
const ArgHashMap = std.StringHashMap(MatchedArgValue);

pub const MatchedArgValue = union(enum) {
    none,
    single: []const u8,
    many: std.ArrayList([]const u8),

    pub fn count(val: MatchedArgValue) usize {
        if (val.isSingle()) {
            return 1;
        } else if (val.isMany()) {
            return val.many.items.len;
        } else {
            return 0;
        }
    }

    pub fn isNone(self: MatchedArgValue) bool {
        return (!self.isSingle() and !self.isMany());
    }

    pub fn isSingle(self: MatchedArgValue) bool {
        return (self == .single);
    }

    pub fn isMany(self: MatchedArgValue) bool {
        return (self == .many);
    }
};

pub const MatchedSubCommand = struct {
    name: []const u8,
    matches: ?ArgMatches,

    pub fn init(name: []const u8, arg_matches: ?ArgMatches) MatchedSubCommand {
        return MatchedSubCommand{ .name = name, .matches = arg_matches };
    }

    pub fn deinit(self: *MatchedSubCommand) void {
        if (self.matches) |*matches| matches.deinit();
    }
};

/// A structure for querying the parse result.
pub const ArgMatches = struct {
    allocator: std.mem.Allocator,
    args: ArgHashMap,
    subcommand: ?*MatchedSubCommand,

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
            if (value.isMany()) value.many.deinit();
        }
        self.args.deinit();

        if (self.subcommand) |subcommand| {
            subcommand.deinit();
            self.allocator.destroy(subcommand);
        }
    }

    pub fn setSubcommand(self: *ArgMatches, subcommand: MatchedSubCommand) !void {
        if (self.subcommand != null) return;

        var alloc_subcmd = try self.allocator.create(MatchedSubCommand);
        alloc_subcmd.* = subcommand;
        self.subcommand = alloc_subcmd;
    }

    /// Checks if argument or subcommand is present
    pub fn isPresent(self: *const ArgMatches, name_to_lookup: []const u8) bool {
        if (self.args.contains(name_to_lookup)) {
            return true;
        } else if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, name_to_lookup))
                return true;
        }

        return false;
    }

    /// Checks if arguments were present on command line or not
    pub fn hasArgs(self: *const ArgMatches) bool {
        return ((self.args.count() >= 1) or (self.subcommand != null));
    }

    /// Returns the single value of an argument if found otherwise null
    pub fn valueOf(self: *const ArgMatches, arg_name: []const u8) ?[]const u8 {
        if (self.args.get(arg_name)) |value| {
            if (value.isSingle()) return value.single;
        } else if (self.subcommand) |subcmd| {
            if (subcmd.matches) |matches| {
                return matches.valueOf(arg_name);
            }
        }

        return null;
    }

    /// Returns the array of values of an argument if found otherwise null
    pub fn valuesOf(self: *const ArgMatches, name_to_lookup: []const u8) ?[][]const u8 {
        if (self.args.get(name_to_lookup)) |value| {
            if (value.isMany()) return value.many.items[0..];
        }
        return null;
    }

    /// Returns the subcommand `ArgMatches` if subcommand is present otherwise null
    pub fn subcommandContext(self: *const ArgMatches, subcmd_name: []const u8) ?ArgMatches {
        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
                return subcmd.matches;
            }
        }
        return null;
    }
};
