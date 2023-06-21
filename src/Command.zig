const Command = @This();

const std = @import("std");
const help = @import("help.zig");
const Arg = @import("Arg.zig");

const mem = std.mem;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = mem.Allocator;
const EnumSet = std.EnumSet;

pub const Property = enum {
    positional_arg_required,
    subcommand_required,
};

allocator: Allocator,
name: []const u8,
description: ?[]const u8,
positional_args: ArrayListUnmanaged(Arg) = .{},
options: ArrayListUnmanaged(Arg) = .{},
subcommands: ArrayListUnmanaged(Command) = .{},
properties: EnumSet(Property) = .{},

/// Creates a new instance of `Command`.
///
/// **NOTE:** It is generally recommended to use `App.createCommand` to create a
/// new instance of a `Command`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var subcmd1 = app.createCommand("subcmd1", "First Subcommand");
/// var subcmd2 = app.createCommand("subcmd2", "Second Subcommand");
/// ```
pub fn init(allocator: Allocator, name: []const u8, description: ?[]const u8) Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .description = description,
    };
}

/// Deallocates all allocated memory.
pub fn deinit(self: *Command) void {
    self.positional_args.deinit(self.allocator);
    self.options.deinit(self.allocator);

    for (self.subcommands.items) |*subcommand| {
        subcommand.deinit();
    }
    self.subcommands.deinit(self.allocator);
}

/// Appends the new argument to the list of arguments.
///
/// **NOTE:** It returns an `error.DuplicatePositionalArgIndex` when attempting
/// to append two positional arguments with the same index. See the examples below.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.booleanOption("version", 'v', "Show version number"));
///
/// var test = app.createCommand("test", "Run test");
/// try test.addArg(Arg.positional("FILE", null, null));
/// ```
///
/// Appending two positional arguments with the same index.
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.positional("FIRST", null, 1));
/// // Returns `error.DuplicatePositionalArgIndex`
/// try root.addArg(Arg.positional("SECOND", null, 1));
/// ```
pub fn addArg(self: *Command, new_arg: Arg) !void {
    var arg = new_arg;
    const is_positional = (arg.short_name == null) and (arg.long_name == null);

    if (!is_positional) {
        return self.options.append(self.allocator, arg);
    }

    if (arg.index != null) {
        // Check whether any positional argument has the same index as arg.
        for (self.positional_args.items) |positional_arg| {
            std.debug.assert(positional_arg.index != null);

            if (positional_arg.index.? == arg.index.?) {
                return error.DuplicatePositionalArgIndex;
            }
        }
        return self.positional_args.append(self.allocator, arg);
    }

    // Index is not set but it is the first positional argument.
    if (self.positional_args.items.len == 0) {
        arg.setIndex(1);
        return self.positional_args.append(self.allocator, arg);
    }

    // Index is not set and it is not the first positional argument.
    var highest_index: usize = 1;

    for (self.positional_args.items) |positional_arg| {
        std.debug.assert(positional_arg.index != null);

        if (positional_arg.index.? > highest_index) {
            highest_index = positional_arg.index.?;
        }
    }
    arg.setIndex(highest_index + 1);
    try self.positional_args.append(self.allocator, arg);
}

/// Appends multiple arguments to the list of arguments.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArgs(&[_]Arg {
///     Arg.singleValueOption("firstname", 'f', "First name"),
///     Arg.singleValueOption("lastname", 'l', "Last name"),
/// });
///
/// var address = app.createCommand("address", "Address");
/// try address.addArgs(&[_]Arg {
///     Arg.singleValueOption("street", 's', "Street name"),
///     Arg.singleValueOption("postal", 'p', "Postal code"),
/// });
/// ```
pub fn addArgs(self: *Command, args: []Arg) !void {
    for (args) |arg| try self.addArg(arg);
}

/// Appends the new subcommand to the list of subcommands.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var test = app.createCommand("test", "Run test");
/// try test.addArg(Arg.positional("FILE", null, null));
///
/// try root.addSubcommand(test);
/// ```
pub fn addSubcommand(self: *Command, new_subcommand: Command) !void {
    return self.subcommands.append(self.allocator, new_subcommand);
}

/// Appends multiple subcommands to the list of subcommands.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// try root.addSubcommands(&[_]Command{
///     app.createCommand("init-exe", "Initilize the project"),
///     app.createCommand("build", "Build the project"),
/// });
/// ```
pub fn addSubcommands(self: *Command, subcommands: []Command) !void {
    for (subcommands) |subcmd| try self.addSubcommand(subcmd);
}

/// Sets a property to the command, specifying how it should be parsed and
/// processed.
///
/// ## Examples
///
/// Setting a property to indicate that the positional argument is required:
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// try root.addArg(Arg.positional("SOURCE", "Source file to move", null));
/// try root.addArg(Arg.positional("DEST", "Destination path", null));
/// root.setProperty(.positional_arg_required);
/// ```
pub fn setProperty(self: *Command, property: Property) void {
    return self.properties.insert(property);
}

/// Unsets a property from the command, reversing its effect on parsing and
/// processing.
pub fn unsetProperty(self: *Command, property: Property) void {
    return self.properties.remove(property);
}

/// Checks if the command has a specific property set.
///
/// **NOTE:** This function is primarily used by the parser to determine the
/// presence of a specific property for the command.
pub fn hasProperty(self: *const Command, property: Property) bool {
    return self.properties.contains(property);
}

/// Returns the count of positional arguments in the positional argument list.
///
/// **NOTE:** This function is primarily used by the parser to determine the
/// total number of valid positional arguments.
pub fn countPositionalArgs(self: *const Command) usize {
    return (self.positional_args.items.len);
}

/// Returns the count of options in the option list.
///
/// **NOTE:** This function is primarily used by the parser to determine the
/// total number of valid options.
pub fn countOptions(self: *const Command) usize {
    return (self.options.items.len);
}

/// Returns the count of subcommands in the subcommand list.
///
/// **NOTE:** This function is primarily used by the parser to determine the
/// total number of valid subcommands.
pub fn countSubcommands(self: *const Command) usize {
    return (self.subcommands.items.len);
}

/// Performs a linear search to find a positional argument with the given index.
///
/// **NOTE:** This function is primarily used by the parser to find a positional
/// argument based on its index.
pub fn findPositionalArgByIndex(self: *const Command, index: usize) ?*const Arg {
    for (self.positional_args.items) |*pos_arg| {
        std.debug.assert(pos_arg.index != null);

        if (pos_arg.index.? == index) {
            return pos_arg;
        }
    }
    return null;
}

/// Performs a linear search to find a short option with the given short name.
///
/// **NOTE:** This function is primarily used by the parser to find a short option
/// based on its short name.
pub fn findShortOption(self: *const Command, short_name: u8) ?*const Arg {
    for (self.options.items) |*arg| {
        if (arg.short_name) |s| {
            if (s == short_name) return arg;
        }
    }
    return null;
}

/// Performs a linear search to find a long option with the given long name.
///
/// **NOTE:** This function is primarily used by the parser to find a long option
/// based on its long name.
pub fn findLongOption(self: *const Command, long_name: []const u8) ?*const Arg {
    for (self.options.items) |*arg| {
        if (arg.long_name) |l| {
            if (mem.eql(u8, l, long_name)) return arg;
        }
    }
    return null;
}

/// Performs a linear search to find a subcommand with the given subcommand name.
///
/// **NOTE:** This function is primarily used by the parser to find a subcommand
/// based on its name.
pub fn findSubcommand(self: *const Command, provided_subcmd: []const u8) ?*const Command {
    for (self.subcommands.items) |*subcmd| {
        if (std.mem.eql(u8, subcmd.name, provided_subcmd)) {
            return subcmd;
        }
    }

    return null;
}
