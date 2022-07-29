const ArgsContext = @This();
const std = @import("std");
const ArgHashMap = std.StringHashMap(MatchedArg.Value);

pub const MatchedArg = struct {
    pub const Value = union(enum) {
        none,
        single: []const u8,
        many: std.ArrayList([]const u8),

        pub fn isNone(self: Value) bool {
            return (!self.isSingle() and !self.isMany());
        }

        pub fn isSingle(self: Value) bool {
            return (self == .single);
        }

        pub fn isMany(self: Value) bool {
            return (self == .many);
        }
    };

    name: []const u8,
    value: Value,

    fn init(name: []const u8) MatchedArg {
        return MatchedArg{
            .name = name,
            .value = undefined,
        };
    }

    pub fn initWithoutValue(name: []const u8) MatchedArg {
        var self = MatchedArg.init(name);
        self.value = .{ .none = undefined };
        return self;
    }

    pub fn initWithSingleValue(name: []const u8, value: []const u8) MatchedArg {
        var self = MatchedArg.init(name);
        self.value = .{ .single = value };
        return self;
    }

    pub fn initWithManyValues(name: []const u8, values: std.ArrayList([]const u8)) MatchedArg {
        var self = MatchedArg.init(name);
        self.value = .{ .many = values };
        return self;
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

pub fn putMatchedArg(self: *ArgsContext, arg: MatchedArg) !void {
    var maybe_old_value = self.args.getPtr(arg.name);

    if (maybe_old_value) |old_value| {
        // To fix the const error
        var new_value = arg.value;

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

                    const new_key = MatchedArg.Value{ .many = many };
                    return self.args.put(arg.name, new_key);
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
        return self.args.put(arg.name, arg.value);
    }
}

pub fn setSubcommand(self: *ArgsContext, subcommand: MatchedSubCommand) !void {
    var alloc_subcmd = try self.allocator.create(MatchedSubCommand);
    alloc_subcmd.* = subcommand;
    self.subcommand = alloc_subcmd;
}

pub fn isPresent(self: *const ArgsContext, name_to_lookup: []const u8) bool {
    if (self.args.contains(name_to_lookup)) {
        return true;
    } else if (self.subcommand) |subcmd| {
        if (std.mem.eql(u8, subcmd.name, name_to_lookup))
            return true;
    }

    return false;
}

pub fn valueOf(self: *const ArgsContext, arg_name: []const u8) ?[]const u8 {
    if (self.args.get(arg_name)) |value| {
        switch (value) {
            .single => |val| return val,
            else => return null,
        }
    } else if (self.subcommand) |subcmd| {
        if (subcmd.ctx) |ctx| {
            return ctx.valueOf(arg_name);
        }
    }

    return null;
}

pub fn valuesOf(self: *ArgsContext, name_to_lookup: []const u8) ?[][]const u8 {
    if (self.args.get(name_to_lookup)) |value| {
        switch (value) {
            .many => |*v| return v.items[0..],
            else => return null,
        }
    } else {
        return null;
    }
}

pub fn subcommandContext(self: *const ArgsContext, subcmd_name: []const u8) ?ArgsContext {
    if (self.subcommand) |subcmd| {
        if (std.mem.eql(u8, subcmd.name, subcmd_name)) {
            return subcmd.ctx;
        }
    }
    return null;
}
