# Upcoming version
## Breaking Changes
- `flag.boolean` is moved and renamed to `Arg.booleanOption`.
- `flag.argOne` is moved and renamed to `Arg.singleArgumentOption`.
- `flag.argN` is moved and renamed to `Arg.multiArgumentsOption` and the order of parameters is slighlty changed.

    Old
    ```zig
    fn(name: []const u8, short_name: ?u8, max_values: usize, description: ?[]const u8) Arg;
    ```

    New
    ```zig
    fn(name: []const u8, short_name: ?u8, description: ?[]const u8, max_values: usize) Arg;
    ```
- `flag.option` is moved and renamed to `Arg.singleArgumentOptionWithValidValues`. Also the signature of function is changed to `fn(name: []const u8, short_name: ?u8, description: ?[]const u8, values: []const []const u8)`.

    Before
    ```zig
    const flag = yazap.flag

    // -- snip --
    try root.addArg(flag.boolean("bool", null, null));
    try root.addArg(flag.argOne("one", null, null));
    try root.addArg(flag.argN("many", null, 2, null));
    try root.addArg(flag.option("opt", null, &[_][]const u8 {
        "opt1",
        "opt2",
    }, null));
    // -- snip --
    ```

    After
    ```zig
    const Arg = yazap.Arg

    // -- snip --
    try root.addArg(Arg.booleanOption("bool", null, null));
    try root.addArg(Arg.singleArgumentOption("one", null, null));
    try root.addArg(Arg.multiArgumentsOption("many", null, null, 2));
    try root.addArg(Arg.singleArgumentOptionWithValidValues("opt", null, null, &[_][]const u8 {
        "opt1",
        "opt2",
    }));
    // -- snip --
    ```
- `Arg.allowed_values` is renamed to `Arg.valid_values`.
- `Arg.setShortNameFromName` is removed.
- `Arg.setNameAsLongName` is removed.
- `Arg.setAllowedValues` is renamed to `Arg.setValidValues`.
- `Arg.setSetting` is renamed to `Arg.addProperty`.
- `Arg.unsetSetting` is renamed to `Arg.removeProperty`.
- `Arg.isSettingSet` is renamed to `Arg.hasProperty`.
- `Command.takesSingleValue` and `Command.takesNValues` are removed, use new `Arg.positional` instead.
- `Command.countArgs` is renamed to `Command.countPositionalArgs`.
- `Command.setSetting` is renamed to `Command.addProperty`.
- `Command.unsetSetting` is renamed to `Command.removeProperty`.
- `Command.isSettingSet` is renamed to `Command.hasProperty`.

## What's New
- Added new `Arg.multiArgumentsOptionWithValidValues` API
- Added new `Arg.positional` API for creating a new positional argument and with this changes it's no
longer required to set `.takes_positional_arg` property to root `Command`.

    Before
    ```zig
    var root = app.rootCommand();

    try root.takesSingleValue("ONE");
    try root.takesSingleValue("TWO");
    try root.takesSingleValue("THREE");
    root.setSetting(.takes_positional_arg);
    ```

    After
    ```zig
    const Arg = yazap.Arg;

    var root = app.rootCommand();

    // Arg.positional(name: []const u8, description: ?[]const u8, index: ?usize)
    
    // Order dependent
    try root.addArg(Arg.positional("ONE", null, null));
    try root.addArg(Arg.positional("TWO", null, null));
    try root.addArg(Arg.positional("THREE", null, null));

    // Equivalent but order independent
    try root.addArg(Arg.positional("THREE", null, 3));
    try root.addArg(Arg.positional("TWO", null, 2));
    try root.addArg(Arg.positional("ONE", null, 1));

    ```

## Internal Changes
- `enable_help` property is removed and no longer needed to set for a command
which basically means `-h` and `--help` options will be always available to root command and subcommands.
