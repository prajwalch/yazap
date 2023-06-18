//! Represents the argument for your command.

const Arg = @This();
const std = @import("std");

const DEFAULT_VALUES_DELIMITER = ",";

pub const Property = enum {
    takes_value,
    takes_multiple_values,
    allow_empty_value,
};

name: []const u8,
description: ?[]const u8,
short_name: ?u8 = null,
long_name: ?[]const u8 = null,
min_values: ?usize = null,
max_values: ?usize = null,
valid_values: ?[]const []const u8 = null,
values_delimiter: ?[]const u8 = null,
index: ?usize = null,
properties: std.EnumSet(Property) = .{},

// # Constructors

/// Creates a new instance of `Arg`.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var verbose = Arg.init("verbose", "Enable verbose output");
/// verbose.setShortName('v');
///
/// try root.addArg(Arg);
/// ```
pub fn init(name: []const u8, description: ?[]const u8) Arg {
    return Arg{ .name = name, .description = description };
}

/// Creates a boolean option to enable or disable a specific feature or behavior.
///
/// This option represents a simple on/off switch that can be used to control a
/// boolean setting in the application.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.booleanOption("version", 'v', "Show version number"));
/// ```
pub fn booleanOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    return arg;
}

/// Creates an option that accepts a single value.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.singleValueOption("port", 'p', "Port number to bind"));
/// ```
pub fn singleValueOption(name: []const u8, short_name: ?u8, description: ?[]const u8) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    arg.setProperty(.takes_value);
    return arg;
}

/// Creates an option that accepts a single value from a predefined set of values.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.singleValueOptionWithValidValues(
///     "output", 'o', "Output format", &[_][]const u8 { "json", "xml", "csv" },
/// ));
/// ```
pub fn singleValueOptionWithValidValues(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    values: []const []const u8,
) Arg {
    var arg = Arg.singleValueOption(name, short_name, description);
    arg.setValidValues(values);
    return arg;
}

/// Creates an option that accepts multiple values.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.multiValuesOption("nums", 'n', "Numbers to add", 2));
/// ```
pub fn multiValuesOption(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    max_values: usize,
) Arg {
    var arg = Arg.init(name, description);

    if (short_name) |n| {
        arg.setShortName(n);
    }
    arg.setLongName(name);
    arg.setMinValues(1);
    arg.setMaxValues(max_values);
    arg.setDefaultValuesDelimiter();
    arg.setProperty(.takes_value);
    return arg;
}

/// Creates an option that accepts multiple values from a predefined set of
/// valid values.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// try root.addArg(Arg.multiValuesOptionWithValidValues(
///     "distros", 'd', "Two Fav Distros", 2, &[_]const u8 { "debian", "ubuntu", "arch" },
/// ));
/// ```
pub fn multiValuesOptionWithValidValues(
    name: []const u8,
    short_name: ?u8,
    description: ?[]const u8,
    max_values: usize,
    values: []const []const u8,
) Arg {
    var arg = Arg.multiValuesOption(name, short_name, description, max_values);
    arg.setValidValues(values);
    return arg;
}

/// Creates a positional argument.
///
/// The index starts with **1** and determines the position of the positional
/// argument relative to other positional arguments. By default, the index is
/// assigned based on the order in which the arguments are defined.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// // Order dependent
/// try root.addArg(Arg.positional("FIRST", null, null));
/// try root.addArg(Arg.positional("SECOND", null, null));
/// try root.addArg(Arg.positional("THIRD", null, null));
///
/// // Equivalent but order independent
/// try root.addArg(Arg.positional("THIRD", null, 3));
/// try root.addArg(Arg.positional("SECOND", null, 2));
/// try root.addArg(Arg.positional("FIRST", null, 1));
/// ```
pub fn positional(name: []const u8, description: ?[]const u8, index: ?usize) Arg {
    var arg = Arg.init(name, description);

    if (index) |i| {
        arg.setIndex(i);
    }
    arg.setProperty(.takes_value);
    return arg;
}

// # Setters

/// Sets the short name of the argument.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var port = Arg.init("port", "Port number to bind");
/// port.setShortName('p');
/// port.setProperty(.takes_value);
///
/// // Equivalent, except `singleValueOption` sets the long name as well.
/// var port = Arg.singleValueOption("port", 'p', "Port number to bind");
///
/// try root.addArg(port);
/// ```
pub fn setShortName(self: *Arg, short_name: u8) void {
    self.short_name = short_name;
}

/// Sets the long name of the argument.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var port = Arg.init("port", "Port number to bind");
/// port.setLongName("port");
/// port.setProperty(.takes_value);
///
/// // Equivalent
/// var port = Arg.singleValueOption("port", null, "Port number to bind");
///
/// try root.addArg(port);
/// ```
pub fn setLongName(self: *Arg, long_name: []const u8) void {
    self.long_name = long_name;
}

/// Sets the minimum number of values required for an argument.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var nums = Arg.init("nums", "Numbers to add");
/// nums.setShortName('n');
/// nums.setMinValues(2);
/// nums.setProperty(.takes_value);
///
/// try root.addArg(nums);
/// ```
pub fn setMinValues(self: *Arg, num: usize) void {
    self.min_values = if (num >= 1) num else null;
}

/// Sets the maximum number of values an argument can take.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var nums = Arg.init("nums", "Numbers to add");
/// nums.setShortName('n');
/// nums.setLongName("nums");
/// nums.setMinValues(2);
/// nums.setMaxValues(5);
/// nums.setProperty(.takes_value);
///
/// try root.addArg(nums);
/// ```
pub fn setMaxValues(self: *Arg, num: usize) void {
    self.max_values = if (num >= 1) num else null;
}

/// Sets the valid values for an argument.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var distros = Arg.init("distros", "Two Fav Distros");
/// distros.setShortName('d');
/// distros.setLongName("distros");
/// distros.setMinValues(1);
/// distros.setMaxValues(2);
/// distros.setValidValues(&[_][]const u8{
///     "debian",
///     "ubuntu",
///     "arch",
/// });
/// distros.setProperty(.takes_value);
///
/// // Equivalent
/// var distros = Arg.multiValuesOptionWithValidValues(
///     "distros", 'd', "Two Fav Distros", 2, &[_]const u8 { "debian", "ubuntu", "arch" },
/// );
///
/// try root.addArg(distros);
/// ```
pub fn setValidValues(self: *Arg, values: []const []const u8) void {
    self.valid_values = values;
}

/// Sets the default separator for values of an argument.
/// This separator is used when multiple values are provided for the argument.
/// Use `Arg.setValuesDelimiter` to set a custom delimiter.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var nums = Arg.init("nums", "Numbers to add");
/// nums.setShortName("n");
/// nums.setLongName("nums");
/// nums.setMinValues(2);
/// nums.setDefaultValuesDelimiter();
/// nums.setProperty(.takes_value);
///
/// try root.addArg(nums);
///
/// // Command line input: myapp --nums 1,2
/// ```
pub fn setDefaultValuesDelimiter(self: *Arg) void {
    self.setValuesDelimiter(DEFAULT_VALUES_DELIMITER);
}

/// Sets the given separator for values of an argument.
/// This separator is used when multiple values are provided for the argument.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var nums = Arg.init("nums", "Numbers to add");
/// nums.setShortName("n");
/// nums.setLongName("nums");
/// nums.setMinValues(2);
/// nums.setValuesDelimiter(":");
/// nums.setProperty(.takes_value);
///
/// try root.addArg(nums);
///
/// // Command line input: myapp --nums 1:2
/// ```
pub fn setValuesDelimiter(self: *Arg, delimiter: []const u8) void {
    self.values_delimiter = delimiter;
}

/// Sets the index of a positional argument, starting with **1**.
///
/// The index determines the position of the positional argument relative to
/// other positional arguments. By default, the index is assigned based on the
/// order in which the arguments are defined.
///
/// **NOTE:** Setting index for options will have no effect and will be sliently
/// ignored.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var second = Arg.init("SECOND", "Second positional arg");
/// second.setIndex(2);
/// second.setProperty(.takes_value);
///
/// // Equivalent
/// var second = Arg.positional("SECOND", "Second positional arg", 2);
///
/// var first = Arg.init("FIRST", "First positional arg");
/// first.setIndex(1);
/// first.setProperty(.takes_value);
///
/// // Equivalent
/// var first = Arg.positional("FIRST", "First positional arg", 2);
///
/// // No effect on this
/// var option = Arg.singleValueOption("option", 'o', "Some description");
/// option.setIndex(3);
///
/// try root.addArg(first);
/// try root.addArg(second);
/// try root.addArg(option);
///
/// // Command line examples:
/// //  - myapp firstvalue secondvalue
/// //  - myapp firstvalue secondvalue --option optionvalue
/// //  - myapp --option optionvalue firstvalue secondvalue
/// ```
pub fn setIndex(self: *Arg, index: usize) void {
    self.index = index;
}

/// Sets a property to the argument, specifying how it should be parsed and processed.
///
/// ## Examples
///
/// Setting a property to indicate that the argument takes a value from the command line:
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var name = Arg.init("name", "Person to greet");
/// name.setShortName('n');
/// name.setProperty(.takes_value);
///
/// try root.addArg(name);
///
/// // Command line input: myapp -n foo
/// ```
pub fn setProperty(self: *Arg, property: Property) void {
    return self.properties.insert(property);
}

/// Unsets a property from the argument, reversing its effect on parsing and processing.
///
/// ## Examples
///
/// Removing a property to indicate that the argument no longer takes a value from the command line:
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var name = Arg.singleValueOption("name", 'n', "Person to greet");
/// // Convert to boolean option by removing the `takes_value` property
/// name.unsetProperty(.takes_value);
///
/// try root.addArg(name);
/// ```
pub fn unsetProperty(self: *Arg, property: Property) void {
    return self.properties.remove(property);
}

// # Getters

/// Checks if the argument has a specific property set.
///
/// **NOTE:** This function is primarily used by the parser to determine the
/// presence of a specific property for the argument.
///
/// ## Examples
///
/// Checking if the argument takes a value from the command line:
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
///
/// var name = Arg.singleValueOption("name", 'n', "Person to greet");
/// if (name.hasProperty(.takes_value)) {
///     std.debug.print("The `name` flag takes a value", .{});
/// }
///
/// try root.addArg(name);
/// ```
pub fn hasProperty(self: *const Arg, property: Property) bool {
    return self.properties.contains(property);
}

/// Checks whether a given value is valid or not.
///
/// **NOTE:** If `Arg.valid_values` is not set through `Arg.setValidValues`,
/// this function always returns true.
///
/// **NOTE:** This function is primarily used by the parser to determine whether
/// the value present on the command line is valid or not.
///
/// ## Examples
///
/// ```zig
/// var app = App.init(allocator, "myapp", "My app description");
/// defer app.deinit();
///
/// var root = app.rootCommand();
/// var color = Arg.singleValueOptionWithValidValues(
///     "color", 'c', "Your Favorite Color", &[_]const u8 { "blue", "red" },
/// );
///
/// if (color.isValidValue("foo")) {
///     std.debug.print("Foo is not a valid color");
/// }
///
/// try root.addArg(color);
/// ```
pub fn isValidValue(self: *const Arg, value_to_check: []const u8) bool {
    if (self.valid_values) |values| {
        for (values) |value| {
            if (std.mem.eql(u8, value, value_to_check)) return true;
        }
        return false;
    }
    return true;
}
