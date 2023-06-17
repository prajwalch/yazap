# Upcoming version

## Breaking Changes

### `flag` Changes
- Moved and Renamed `boolean` to `Arg.booleanOption`.
- Moved and Renamed `argOne` to `Arg.singleArgumentOption`.
- Moved and Renamed `argN` to `Arg.multiArgumentsOption` with slightly
    modified parameter order.

    Old
    ```zig
    fn(name: []const u8, short_name: ?u8, max_values: usize, description: ?[]const u8) Arg;
    ```

    New
    ```zig
    fn(name: []const u8, short_name: ?u8, description: ?[]const u8, max_values: usize) Arg;
    ```

- Moved and Renamed `option` to `Arg.singleArgumentOptionWithValidValues` with
slightly modified parameter order.

    Old
    ```zig
    fn(name: []const u8, short_name: ?u8, values: []const []const u8, description: ?[]const u8);
    ```
    
    New
    ```zig
    fn(name: []const u8, short_name: ?u8, description: ?[]const u8, values: []const []const u8);
    ```

#### Examples 

Before:
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

After:
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

### `Command` Changes
- Renamed `countArgs()` to `countPositionalArgs()`.
- Renamed `setSetting()` to `setProperty()`.
- Renamed `unsetSetting()` to `unsetProperty()`.
- Renamed `isSettingSet()` to `hasProperty()`.
- Removed `takesSingleValue()` and `takesNValues()`, use new `Arg.positional`
instead.

### `Arg` Changes
- Renamed `allowed_values` to `valid_values`.
- Renamed `setAllowedValues()` to `setValidValues()`.
- Renamed `setSetting()` to `setProperty()`.
- Renamed `unsetSetting()` to `unsetProperty()`.
- Renamed `isSettingSet()` to `hasProperty()`.
- Removed `setShortNameFromName()`.
- Removed `setNameAsLongName()`.

### `ArgsContext` Changes
- Renamed `ArgsContext` to `ArgMatches`.
- Renamed `isPresent()` to `isArgumentPresent()`.
- Renamed `hasArgs()` to `hasArguments()`.
- Renamed `subcommandContext()` to `subcommandMatches()`.

## What's New
- Enhanced documentation for `Arg.*` API with detailed explanations and examples.
- Enhanced documentation for `Command.*` API with detailed explanations and examples.
- Introduced `Arg.multiArgumentsOptionWithValidValues` API to support creating
an argument that can take multiple arguments from pre-defined values.
- Introduced `Arg.positional` API, eliminating the need to set the
`.takes_positional_arg` property for commands. This simplifies the
process of creating positional arguments.

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
- Removed `enable_help` property for commands, making `-h` and `--help` options
always available for both the root command and subcommands.
