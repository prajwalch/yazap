const Command = @This();

const std = @import("std");
const Arg = @import("Arg.zig");

const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const EnumSet = std.EnumSet;
const default_init_array_capacity = 10;

/// Represents the different parsing behaviors that can be applied to a
/// command.
pub const Property = enum {
    /// Configures to display help when arguments are not provided.
    help_on_empty_args,
    /// Specifies that a positional argument must be provided for the command.
    positional_arg_required,
    /// Specifies that a subcommand must be provided for the command.
    subcommand_required,
};

allocator: Allocator,
name: []const u8,
description: ?[]const u8,
positional_args: ArrayList(Arg),
options: ArrayList(Arg),
subcommands: ArrayList(Command),
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
pub fn init(allocator: Allocator, name: []const u8, description: ?[]const u8) !Command {
    return Command{
        .allocator = allocator,
        .name = name,
        .description = description,
        .positional_args = try ArrayList(Arg).initCapacity(allocator, default_init_array_capacity),
        .options = try ArrayList(Arg).initCapacity(allocator, default_init_array_capacity),
        .subcommands = try ArrayList(Command).initCapacity(allocator, default_init_array_capacity),
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
/// // Returns `error.DuplicatePositionalArgIndex`.
/// try root.addArg(Arg.positional("SECOND", null, 1));
/// ```
pub fn addArg(self: *Command, arg: Arg) !void {
    var new_arg = arg;
    const is_positional = (arg.short_name == null) and (arg.long_name == null);

    // If its not a positional argument, append it and return.
    if (!is_positional) {
        return self.options.append(self.allocator, new_arg);
    }

    // Its a positonal argument.
    //
    // If the position is set check for position duplication.
    if (new_arg.index != null) {
        for (self.positional_args.items) |positional_arg| {
            std.debug.assert(positional_arg.index != null);

            if (positional_arg.index.? == new_arg.index.?) {
                return error.DuplicatePositionalArgIndex;
            }
        }
        // No duplication; append it.
        return self.positional_args.append(self.allocator, new_arg);
    }

    // If the position is not set and if its the first positional argument
    // then return immediately by giving it first position.
    if (self.positional_args.items.len == 0) {
        new_arg.setIndex(1);
        return self.positional_args.append(self.allocator, new_arg);
    }

    // If the position is not set and if its not first positional argument
    // then find the next position for it.
    var current_position: usize = 1;

    for (self.positional_args.items) |positional_arg| {
        std.debug.assert(positional_arg.index != null);

        if (positional_arg.index.? > current_position) {
            current_position = positional_arg.index.?;
        }
    }

    new_arg.setIndex(current_position + 1);
    try self.positional_args.append(self.allocator, new_arg);
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
pub fn addArgs(self: *Command, args: []const Arg) !void {
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
pub fn addSubcommands(self: *Command, subcommands: []const Command) !void {
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
/// **NOTE:** This function is primarily used by the parser.
pub fn hasProperty(self: *const Command, property: Property) bool {
    return self.properties.contains(property);
}

/// Returns the count of positional arguments in the positional argument list.
///
/// **NOTE:** This function is primarily used by the parser.
pub fn countPositionalArgs(self: *const Command) usize {
    return (self.positional_args.items.len);
}

/// Returns the count of options in the option list.
///
/// **NOTE:** This function is primarily used by the parser.
pub fn countOptions(self: *const Command) usize {
    return (self.options.items.len);
}

/// Returns the count of subcommands in the subcommand list.
///
/// **NOTE:** This function is primarily used by the parser.
pub fn countSubcommands(self: *const Command) usize {
    return (self.subcommands.items.len);
}

/// Performs a linear search to find a positional argument with the given index.
///
/// **NOTE:** This function is primarily used by the parser.
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
/// **NOTE:** This function is primarily used by the parser.
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
/// **NOTE:** This function is primarily used by the parser.
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
/// **NOTE:** This function is primarily used by the parser.
pub fn findSubcommand(self: *const Command, subcommand: []const u8) ?*const Command {
    for (self.subcommands.items) |*subcmd| {
        if (std.mem.eql(u8, subcmd.name, subcommand)) {
            return subcmd;
        }
    }

    return null;
}
