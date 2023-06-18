const std = @import("std");
const Arg = @import("Arg.zig");
const ArgHashMap = std.StringHashMap(MatchedArgValue);

pub const MatchedArgValue = union(enum) {
    none,
    single: []const u8,
    many: std.ArrayList([]const u8),

    pub fn count(value: MatchedArgValue) usize {
        if (value.isSingle()) {
            return 1;
        } else if (value.isMany()) {
            return value.many.items.len;
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

    /// Checks whether any arguments were present on the command line.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var app = App.init(allocator, "myapp", "My app description");
    /// defer app.deinit();
    ///
    /// var root = app.rootCommand();
    /// try root.addArg(Arg.booleanOption("verbose", 'v', "Enable verbose output"));
    /// try root.addSubcommand(app.createCommand("init-exe", "Initilize project"));
    ///
    /// const matches = try app.parseProcess();
    ///
    /// if (!matches.hasArgs()) {
    ///     try app.displayHelp();
    ///     return;
    /// }
    /// ```
    pub fn hasArgs(self: *const ArgMatches) bool {
        return ((self.args.count() >= 1) or (self.subcommand != null));
    }

    /// Checks whether an option, positional argument or subcommand with the
    /// specified name was present on the command line.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var app = App.init(allocator, "myapp", "My app description");
    /// defer app.deinit();
    ///
    /// var root = app.rootCommand();
    /// try root.addArg(Arg.booleanOption("verbose", 'v', "Enable verbose output"));
    ///
    /// // Define a subcommand
    /// var build_cmd = app.createCommand("build", "Build the project");
    /// try build_cmd.addArg(Arg.booleanOption("release", 'r', "Build in release mode"));
    /// try root.addSubcommand(build_cmd);
    ///
    /// const matches = try app.parseProcess();
    ///
    /// if (matches.isArgumentPresent("verbose")) {
    ///     // Handle verbose operation
    /// }
    ///
    /// if (matches.isArgumentPresent("build")) {
    ///     const build_cmd_matches = matches.subcommandMatches("build").?;
    ///
    ///     if (build_cmd_matches.isArgumentPresent("release")) {
    ///         // Build for release mode
    ///     }
    /// }
    ///
    /// ```
    pub fn isArgumentPresent(self: *const ArgMatches, name: []const u8) bool {
        if (self.args.contains(name)) {
            return true;
        } else if (self.subcommand) |subcmd| {
            return std.mem.eql(u8, subcmd.name, name);
        }
        return false;
    }

    /// Returns the value of an option or positional argument if it was present
    /// on the command line; otherwise, returns `null`.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var app = App.init(allocator, "myapp", "My app description");
    /// defer app.deinit();
    ///
    /// var root = app.rootCommand();
    /// try root.addArg(Arg.singleValueOption("config", 'c', "Config file"));
    ///
    /// const matches = try app.parseProcess();
    ///
    /// if (matches.getSingleValue("config")) |config_file| {
    ///     std.debug.print("Config file name: {s}", .{config_file});
    /// }
    /// ```
    pub fn getSingleValue(self: *const ArgMatches, arg_name: []const u8) ?[]const u8 {
        if (self.args.get(arg_name)) |value| {
            if (value.isSingle()) return value.single;
        }
        return null;
    }

    /// Returns the values of an option if it was present on the command line;
    /// otherwise, returns `null`.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var app = App.init(allocator, "myapp", "My app description");
    /// defer app.deinit();
    ///
    /// var root = app.rootCommand();
    /// try root.addArg(Arg.multiValuesOption("nums", 'n', "Numbers to add", 2));
    ///
    /// const matches = try app.parseProcess();
    ///
    /// if (matches.getArgumentValues("nums")) |numbers| {
    ///     std.debug.print("Add {s} + {s}", .{ numbers[0], numbers[1] });
    /// }
    /// ```
    pub fn getArgumentValues(self: *const ArgMatches, name: []const u8) ?[][]const u8 {
        if (self.args.get(name)) |value| {
            if (value.isMany()) return value.many.items[0..];
        }
        return null;
    }

    /// Returns the `ArgMatches` for a specific subcommand if it was present on
    /// on the command line; otherwise, returns `null`.
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var app = App.init(allocator, "myapp", "My app description");
    /// defer app.deinit();
    ///
    /// var root = app.rootCommand();
    ///
    /// var build_cmd = app.createCommand("build", "Build the project");
    /// try build_cmd.addArg(Arg.booleanOption("release", 'r', "Build in release mode"));
    /// try build_cmd.addArg(Arg.singleValueOption("target", 't', "Build for given target"));
    /// try root.addSubcommand(build_cmd);
    ///
    /// const matches = try app.parseProcess();
    ///
    /// if (matches.subcommandMatches("build")) |build_cmd_matches| {
    ///     if (build_cmd_matches.isArgumentPresent("release")) {
    ///         const target = build_cmd_matches.getSingleValue("target") orelse "default";
    ///         // Build for release mode to given target
    ///     }
    /// }
    ///
    /// ```
    pub fn subcommandMatches(self: *const ArgMatches, name: []const u8) ?ArgMatches {
        if (self.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd.name, name)) {
                return subcmd.matches;
            }
        }
        return null;
    }
};
