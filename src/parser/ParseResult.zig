//! Core structure containing parse result.
const ParseResult = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocatorError = Allocator.Error;
const Command = @import("../Command.zig");

/// Map of every parsed arguments.
pub const ArgHashMap = std.StringHashMap(MatchedArgValue);

allocator: Allocator,
/// The command that this result belongs to.
command: ParsedCommand,
/// Parsed arguments (user-defined).
args: ArgHashMap,
/// Indicates the presence of help flag.
///
/// Since help flag is a built-in and special flag, it is not stored in the map
/// where parsed arguments (user-defined) are stored.
contains_help_flag: bool = false,
/// Parse result of a subcommand.
subcmd_parse_result: ?*ParseResult = null,

/// Creates an empty result for the given command.
pub fn init(allocator: Allocator, command: *const Command) ParseResult {
    return ParseResult{
        .allocator = allocator,
        .command = ParsedCommand.init(command, null),
        .args = ArgHashMap.init(allocator),
    };
}

/// Deinitilizes the structure by freeing all the allocated memory.
pub fn deinit(self: *ParseResult) void {
    self.command.deinit();

    var args_value_iter = self.args.valueIterator();
    while (args_value_iter.next()) |value| {
        if (value.isMany()) value.many.deinit();
    }
    self.args.deinit();

    if (self.subcmd_parse_result) |subcmd_parse_result| {
        subcmd_parse_result.deinit();
        self.allocator.destroy(subcmd_parse_result);
    }
    self.subcmd_parse_result = null;
}

/// Returns the command that this result belongs to.
pub fn getCommand(self: *const ParseResult) *const ParsedCommand {
    return &self.command;
}

/// Returns the parsed arguments (user-defined).
pub fn getArgs(self: *const ParseResult) *const ArgHashMap {
    return &self.args;
}

/// Recursively searches and returns a command containing help flag.
pub fn getCommandContainingHelpFlag(self: *const ParseResult) ?*const ParsedCommand {
    // If the current command contains it then return it.
    if (self.contains_help_flag) {
        return self.getCommand();
    }

    // Otherwise, if the command has any subcommand then try to find and return
    // nested subcommand.
    if (self.getSubcommandParseResult()) |subcmd_parse_result| {
        return subcmd_parse_result.getCommandContainingHelpFlag();
    }

    // Neither the current command nor the subcommand or nested subcommand
    // contains help flag.
    return null;
}

/// Returns the subcommand that is active on the command line.
///
/// For e.x.: if **`myapp subcmd1 subcmd1.1 subcmd1.2`** were passed on the
/// command line then **`subcmd1.2`** would be the active subcommand, not
/// the **`subcmd1`** or **`subcmd1.1`**.
pub fn getActiveSubcommand(self: *const ParseResult) ?*const ParsedCommand {
    const subcmd_parse_result = self.getSubcommandParseResult() orelse return null;

    // If any nested subcommand is active then return it.
    if (subcmd_parse_result.getActiveSubcommand()) |active_nested_subcmd| {
        return active_nested_subcmd;
    }

    // Otherwise return the current subcommand.
    return subcmd_parse_result.getCommand();
}

/// Returns the parse result of a subcommand.
pub fn getSubcommandParseResult(self: *const ParseResult) ?*const ParseResult {
    return @as(?*const ParseResult, self.subcmd_parse_result);
}

/// Returns `true` if the result is completely empty.
pub fn isEmpty(self: *const ParseResult) bool {
    return (self.getArgs().count() == 0) and (self.getSubcommandParseResult() == null);
}

/// Inserts a given name-value pair into the map.
///
/// If the map already contains the name, value will be updated and if it didn't
/// a new name-value pair is created.
pub fn insertMatchedArg(
    self: *ParseResult,
    name: []const u8,
    value: MatchedArgValue,
) AllocatorError!void {
    errdefer if (value.isMany()) value.many.deinit();

    const old_value = self.args.getPtr(name) orelse {
        // Map don't have an entry; create a new pair.
        return self.args.put(name, value);
    };
    // Redeclaration; so that we can mutate.
    var new_value = value;

    switch (old_value.*) {
        .none => if (!new_value.isNone()) {
            return self.args.put(name, new_value);
        },
        .single => |old_single_value| {
            if (new_value.isSingle()) {
                // If both old and new value are single then convert them into
                // multiple values by combining them.
                var many = std.ArrayList([]const u8).init(self.allocator);
                try many.append(old_single_value);
                try many.append(new_value.single);

                return self.args.put(name, .{ .many = many });
            } else if (new_value.isMany()) {
                // If old value is single but the new value is many then append
                // the old one into the new one.
                try new_value.many.append(old_single_value);
                return self.args.put(name, new_value);
            }
        },
        .many => |*old_many_values| {
            if (new_value.isSingle()) {
                // If old value is many and the new value is single then append
                // the new single value into the old one.
                try old_many_values.append(new_value.single);
            } else if (new_value.isMany()) {
                // If both old and new value are multiple types then append all
                // new values into the old value.
                try old_many_values.appendSlice(try new_value.many.toOwnedSlice());
            }
        },
    }
}

/// Sets the `bool` flag to indicate the presence of help flag.
pub fn setContainsHelpFlag(self: *ParseResult, contains: bool) void {
    self.contains_help_flag = contains;
}

/// Sets a new parse result of a subcommand.
pub fn setSubcommandParseResult(self: *ParseResult, result: ParseResult) AllocatorError!void {
    if (self.subcmd_parse_result != null) return;

    const subcmd_parse_result = try self.allocator.create(ParseResult);
    subcmd_parse_result.* = result;

    self.subcmd_parse_result = subcmd_parse_result;
}

/// Represents a value for a matched argument.
pub const MatchedArgValue = union(enum) {
    /// Empty value.
    none,
    /// Single value.
    single: []const u8,
    /// Multiple values.
    many: std.ArrayList([]const u8),

    /// Creates an empty type of value.
    pub fn initNone() MatchedArgValue {
        return .none;
    }

    /// Creates a single type of value.
    pub fn initSingle(value: []const u8) MatchedArgValue {
        return .{ .single = value };
    }

    /// Creates a multiple type of value.
    pub fn initMany(values: std.ArrayList([]const u8)) MatchedArgValue {
        return .{ .many = values };
    }

    /// Returns `true` if the value is empty.
    pub fn isNone(self: MatchedArgValue) bool {
        return (!self.isSingle() and !self.isMany());
    }

    /// Returns `true` if the value is single.
    pub fn isSingle(self: MatchedArgValue) bool {
        return (self == .single);
    }

    /// Returns `true` if there are multiple values.
    pub fn isMany(self: MatchedArgValue) bool {
        return (self == .many);
    }

    /// Returns the length of a single value or returns the count of multiple
    /// values.
    pub fn count(value: MatchedArgValue) usize {
        if (value.isSingle()) {
            return 1;
        } else if (value.isMany()) {
            return value.many.items.len;
        } else {
            return 0;
        }
    }
};

/// Represents a parsed command or subcommand.
pub const ParsedCommand = struct {
    /// Name of a command including its parents.
    pub const AbsoluteName = std.ArrayList(u8);

    /// Inner command.
    command: *const Command,
    /// Command name including its parents.
    absolute_name: ?AbsoluteName,

    /// Creates a new parsed command.
    pub fn init(command: *const Command, absolute_name: ?AbsoluteName) ParsedCommand {
        return ParsedCommand{ .command = command, .absolute_name = absolute_name };
    }

    /// Deinitilizes the structure by freeing all the allocated memory.
    pub fn deinit(self: *ParsedCommand) void {
        if (self.absolute_name) |abs_name| {
            abs_name.deinit();
        }
    }

    /// Returns the full name of a command.
    pub fn name(self: *const ParsedCommand) []const u8 {
        if (self.absolute_name) |abs_name| {
            return @as([]const u8, abs_name.items);
        } else {
            return self.deref().name;
        }
    }

    /// Returns the inner command.
    pub fn deref(self: *const ParsedCommand) *const Command {
        return self.command;
    }
};
