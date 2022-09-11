//! A structure for querying the parser result
//! which includes the getting command's raw value, flag's value, subcommand's args result and so on.

const ArgsContext = @This();

const std = @import("std");
const Arg = @import("../Arg.zig");
const ArgHashMap = std.StringHashMap(MatchedArgValue);

pub const MatchedArgValue = union(enum) {
    none,
    single: []const u8,
    many: std.ArrayList([]const u8),

    pub fn initNone() MatchedArgValue {
        return .none;
    }

    pub fn initSingle(val: []const u8) MatchedArgValue {
        return MatchedArgValue{ .single = val };
    }

    pub fn initMany(vals: std.ArrayList([]const u8)) MatchedArgValue {
        return MatchedArgValue{ .many = vals };
    }

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
    ctx: ?ArgsContext,

    pub fn initWithoutArg(name: []const u8) MatchedSubCommand {
        return MatchedSubCommand{
            .name = name,
            .ctx = null,
        };
    }

    pub fn initWithArg(name: []const u8, args_ctx: ArgsContext) MatchedSubCommand {
        var self = initWithoutArg(name);
        self.ctx = args_ctx;
        return self;
    }

    pub fn deinit(self: *MatchedSubCommand) void {
        if (self.ctx) |*ctx| ctx.deinit();
    }
};

allocator: std.mem.Allocator,
args: ArgHashMap,
subcommand: ?*MatchedSubCommand,

pub fn init(allocator: std.mem.Allocator) ArgsContext {
    return ArgsContext{
        .allocator = allocator,
        .args = ArgHashMap.init(allocator),
        .subcommand = null,
    };
}

pub fn deinit(self: *ArgsContext) void {
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

pub fn putMatchedArg(self: *ArgsContext, arg: *const Arg, value: MatchedArgValue) !void {
    if (arg.max_values) |max| {
        if ((value.count()) > max) return error.TooManyArgValue;
    }
    var maybe_old_value = self.args.getPtr(arg.name);

    if (maybe_old_value) |old_value| {
        // To fix the const error
        var new_value = value;

        switch (old_value.*) {
            .none => if (!(new_value.isNone())) {
                return self.args.put(arg.name, new_value);
            },
            .single => |old_single_value| {
                if (new_value.isSingle()) {
                    // If both old and new value are single then
                    // store them in a single ArrayList and create a new key
                    var many = std.ArrayList([]const u8).init(self.allocator);
                    try many.append(old_single_value);
                    try many.append(new_value.single);

                    return self.args.put(arg.name, MatchedArgValue.initMany(many));
                } else if (new_value.isMany()) {
                    // If old value is single but the new value is many then
                    // append the old one into new many value
                    try new_value.many.append(old_single_value);
                    return self.args.put(arg.name, new_value);
                }
            },
            .many => |*old_many_values| {
                if (new_value.isSingle()) {
                    // If old value is many and the new value is single then
                    // append the new single value into old many value
                    try old_many_values.append(new_value.single);
                } else if (new_value.isMany()) {
                    // If both old and new value is many, append all new values into old value
                    try old_many_values.appendSlice(new_value.many.toOwnedSlice());
                }
            },
        }
    } else {
        // We don't have old value, put the new value
        return self.args.put(arg.name, value);
    }
}

pub fn setSubcommand(self: *ArgsContext, subcommand: MatchedSubCommand) !void {
    var alloc_subcmd = try self.allocator.create(MatchedSubCommand);
    alloc_subcmd.* = subcommand;
    self.subcommand = alloc_subcmd;
}

/// Checks if argument or subcommand is present
pub fn isPresent(self: *const ArgsContext, name_to_lookup: []const u8) bool {
    if (self.args.contains(name_to_lookup)) {
        return true;
    } else if (self.subcommand) |subcmd| {
        if (std.mem.eql(u8, subcmd.name, name_to_lookup))
            return true;
    }

    return false;
}

/// Returns the single value of an argument if found otherwise null
pub fn valueOf(self: *const ArgsContext, arg_name: []const u8) ?[]const u8 {
    if (self.args.get(arg_name)) |value| {
        if (value.isSingle()) return value.single;
    } else if (self.subcommand) |subcmd| {
        if (subcmd.ctx) |ctx| {
            return ctx.valueOf(arg_name);
        }
    }

    return null;
}

/// Returns the array of values of an argument if found otherwise null
pub fn valuesOf(self: *const ArgsContext, name_to_lookup: []const u8) ?[][]const u8 {
    if (self.args.get(name_to_lookup)) |value| {
        if (value.isMany()) return value.many.items[0..];
    }
    return null;
}

/// Returns the subcommand `ArgsContext` if subcommand is present otherwise null
pub fn subcommandContext(self: *const ArgsContext, subcmd_name: []const u8) ?ArgsContext {
    if (self.subcommand) |subcmd| {
        if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
            return subcmd.ctx;
        }
    }
    return null;
}

test "emit methods docs" {
    std.testing.refAllDecls(@This());
}
