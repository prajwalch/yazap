# Upcoming version
## Breaking Changes
- `flag.boolean` is moved and renamed to `Arg.booleanOption`.
- `flag.argOne` is moved and renamed to `Arg.singleArgumentOption`.
- `flag.argN` is moved and renamed to `Arg.multiArgumentsOption`.
- `flag.option` is moved and renamed to `Arg.singleArgumentOptionWithValidValues`. Also the signature of function is changed to `fn(name: []const u8, short_name: ?u8, description: ?[]const u8, values: []const []const u8)`.

    ```zig
    // Old
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

    ```zig
    // new
    const Arg = yazap.Arg

    // -- snip --
    try root.addArg(Arg.booleanOption("bool", null, null));
    try root.addArg(Arg.singleArgumentOption("one", null, null));
    try root.addArg(Arg.multiArgumentsOption("many", null, 2, null));
    try root.addArg(Arg.singleArgumentOptionWithValidValues("opt", null, null, &[_][]const u8 {
        "opt1",
        "opt2",
    }));
    // -- snip --
    ```
- `Arg.setShortNameFromName` is removed.
- `Arg.setNameAsLongName` is removed.
- `Arg.setSetting` is renamed to `Arg.addProperty`.
- `Arg.unsetSetting` is renamed to `Arg.removeProperty`.
- `Arg.isSettingSet` is renamed to `Arg.hasProperty`.
- `Command.countArgs` is renamed to `Command.countPositionalArgs`.
- `Command.setSetting` is renamed to `Command.addProperty`.
- `Command.unsetSetting` is renamed to `Command.removeProperty`.
- `Command.isSettingSet` is renamed to `Command.hasProperty`.

## What's New
- Added new `Arg.multiArgumentsOptionWithValidValues` API

## Internal Changes
- `enable_help` property is removed and no longer needed to set for a command
which basically means `-h` and `--help` options will be always available to root command and subcommands.
