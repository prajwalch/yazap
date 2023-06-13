# Upcoming version
## Breaking Changes
- `flag.boolean` is moved and renamed to `Arg.booleanOption`.
- `flag.argOne` is moved and renamed to `Arg.singleArgumentOption`.
- `flag.argN` is moved and renamed to `Arg.multiArgumentsOption`.
- `flag.option` is moved and renamed to `Arg.singleArgumentOptionWithValidValues`.

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
    }));
    // -- snip --
    ```

    ```zig
    // new
    const Arg = yazap.Arg

    // -- snip --
    try root.addArg(Arg.booleanOption("bool", null, null));
    try root.addArg(Arg.singleArgumentOption("one", null, null));
    try root.addArg(Arg.multiArgumentsOption("many", null, 2, null));
    try root.addArg(Arg.singleArgumentOptionWithValidValues("opt", null, &[_][]const u8 {
        "opt1",
        "opt2",
    }));
    // -- snip --
    ```
- `Arg.setShortNameFromName` is removed.
- `Arg.setNameAsLongName` is removed.

## What's New