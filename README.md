[![test](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml)
[![pages-build-deployment](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment)

# Yazap

> **Note**
> This branch targets the [master branch of zig](https://github.com/ziglang/zig).
> Use [v0.9.x-v0.10.x](https://github.com/PrajwalCH/yazap/tree/v0.9.x-v0.10.x) branch
> if you're using an older versions.

The ultimate [zig](https://ziglang.org) library for seamless command-line parsing.
Effortlessly handles options, subcommands, and custom arguments with ease.

Inspired by [clap-rs](https://github.com/clap-rs/clap) and [andrewrk/ziglang: src-self-hosted/arg.zig](https://git.sr.ht/~andrewrk/ziglang/tree/725b6ee634f01355da4a6badc5675751b85f0bf0/src-self-hosted/arg.zig)

## Key Features:

- **Options (short and long)**:
  - Providing values with `=`, space, or no space (`-f=value`, `-f value`, `-fvalue`).
  - Supports delimiter-separated values with `=` or without space (`-f=v1,v2,v3`, `-fv1:v2:v3`).
  - Chaining multiple short boolean options (`-abc`).
  - Providing values and delimiter-separated values for multiple chained options using `=` (`-abc=val`, `-abc=v1,v2,v3`).
  - Specifying an option multiple times (`-a 1 -a 2 -a 3`).

- **Positional arguments**:
  - Supports positional arguments alongside options for more flexible command-line inputs. For example:
    - `command <positional_arg>`
    - `command <arg1> <arg2> <arg3>`

- **Nested subcommands**:
  - Organize commands with nested subcommands for a structured command-line interface. For example:
    - `command subcommand`
    - `command subcommand subsubcommand`

- **Automatic help handling and generation**

- **Custom Argument definition**:
  - Define custom [Argument](https://prajwalch.github.io/yazap/#A;lib:Arg) types for specific application requirements.

## Limitations:

- Does not support delimiter-separated values using space (`-f v1,v2,v3`).
- Does not support providing value and delimiter-separated values for multiple
chained options using space (`-abc value, -abc v1,v2,v3`).

## Installing

Requires [zig v0.11.x](https://ziglang.org).

1. Initialize your project as a repository (if it hasn't been initilized already)
by running `git init`.
2. Create a directory named `libs` in the root of your project.
3. Add the `yazap` library as submodule by running the following command:

    ```bash
    git submodule add https://github.com/PrajwalCH/yazap libs/yazap
    ```
4. After the previous step is completed, add the following code snippet to your
`build.zig` file:

    ```zig
    exe.addAnonymousModule("yazap", .{
        .source_file = .{ .path = "libs/yazap/src/lib.zig" },
    });
    ```
5. You can now import this library in your source file as follows:

    ```zig
    const yazap = @import("yazap");
    ```

## Documentation

For detailed and comprehensive documentation, please visit
[this link](https://prajwalch.github.io/yazap/).

## Building and Running Examples

The examples can be found [here](/examples). To build all of them, run the
following command on your terminal:

```bash
$ zig build examples
```

After the compilation finishes, you can run each example by executing the
corresponding binary:

```bash
$ ./zig-out/bin/example_name
```

To view the usage and available options for each example, you can use `-h` or
`--help` flag:

```bash
$ ./zig-out/bin/example_name --help
```

## Usage

### Initializing Yazap

The begin using `yazap`, the first step is to create an instance of 
[App](https://prajwalch.github.io/yazap/#A;lib:App) by calling
`App.init(allocator, "Your app name", "optional description")`. This function
internally creates a root command for your application.

```zig
var app = App.init(allocator, "myls", "My custom ls");
defer app.deinit();
```

### Obtaining the Root Command

The [App](https://prajwalch.github.io/yazap/#A;lib:App) itself does not provide
any methods for adding arguments to your command. Its main purpose is to
initialize the library, invoke the parser, and free associated structures. To
add arguments and subcommands, you'll need to use the root command.

To obtain the root command, simply call `App.rootCommand()`, which returns a
pointer to it. This gives you access to the core command of your application.

```zig
var myls = app.rootCommand();
```

### Adding Arguments

Once you have obtained the root command, you can proceed to arguments using the
provided methods in the `Command`. For a complete list of available methods,
refer to the [Command API](https://prajwalch.github.io/yazap/#A;lib:Command)
documentation.

```zig
try myls.addArg(Arg.positional("FILE", null, null));
try myls.addArg(Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"));
try myls.addArg(Arg.booleanOption("recursive", 'R', "List subdirectories recursively"));
try myls.addArg(Arg.booleanOption("one-line", '1', null));
try myls.addArg(Arg.booleanOption("size", 's', null));
try myls.addArg(Arg.booleanOption("version", null, null));

try myls.addArg(Arg.singleArgumentOption("ignore", 'I', null));
try myls.addArg(Arg.singleArgumentOption("hide", null, null));

try myls.addArg(Arg.singleArgumentOptionWithValidValues("color", 'C', null, &[_][]const u8{
    "always",
    "auto",
    "never",
}));
```

Alternatively, you can add multiple arguments in a single function call using
`Command.addArgs()`:

```zig
try myls.addArgs(&[_]Arg {
    Arg.positional("FILE", null, null),
    Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"),
    Arg.booleanOption("recursive", 'R', "List subdirectories recursively"),
    Arg.booleanOption("one-line", '1', null),
    Arg.booleanOption("size", 's', null),
    Arg.booleanOption("version", null, null),

    Arg.singleArgumentOption("ignore", 'I', null),
    Arg.singleArgumentOption("hide", null, null),

    Arg.singleArgumentOptionWithValidValues("color", 'C', null, &[_][]const u8{
        "always",
        "auto",
        "never",
    }),
});
```

### Adding Subcommands

To create a subcommand, you can use `App.createCommand("name", "optional description")`.
Once you have created a subcommand, you can add its own arguments and subcommands
just like the root command then add it to the root command using `Command.addSubcommand()`.

```zig
var update_cmd = app.createCommand("update", "Update the app or check for new updates");
try update_cmd.addArg(Arg.booleanOption("check-only", null, "Only check for new update"));
try update_cmd.addArg(Arg.singleArgumentOptionWithValidValues("branch", 'b', "Branch to update", &[_][]const u8{ 
    "stable",
    "nightly",
    "beta"
}));

try myls.addSubcommand(update_cmd);
```

### Parsing Arguments

Once you have finished adding arguments and subcommands, call `App.parseProcess()`
to start the parsing process. This function internally utilizes
[`std.process.argsAlloc`](https://ziglang.org/documentation/master/std/#A;std:process.argsAlloc)
to obtain the raw arguments. Alternatively, you can use `App.parseFrom()` and
pass your own raw arguments, which can be useful during testing. Both functions
return a constant pointer to [`ArgMatches`](https://prajwalch.github.io/yazap/#A;lib:ArgMatches).

```zig
const matches = try app.parseProcess();

if (matches.isArgumentPresent("version")) {
    log.info("v0.1.0", .{});
    return;
}

if (matches.getArgumentValue("FILE")) |f| {
    log.info("List contents of {f}");
    return;
}

if (matches.subcommandMatches("update")) |update_cmd_matches| {
    if (update_cmd_matches.isArgumentPresent("check-only")) {
        std.log.info("Check and report new update", .{});
        return;
    }

    if (update_cmd_matches.getArgumentValue("branch")) |branch| {
        std.log.info("Branch to update: {s}", .{branch});
        return;
    }
    return;
}

if (matches.isArgumentPresent("all")) {
    log.info("show all", .{});
    return;
}

if (matches.isArgumentPresent("recursive")) {
    log.info("show recursive", .{});
    return;
}

if (matches.getArgumentValue("ignore")) |pattern| {
    log.info("ignore pattern = {s}", .{pattern});
    return;
}

if (matches.isArgumentPresent("color")) {
    const when = matches.getArgumentValue("color").?;

    log.info("color={s}", .{when});
    return;
}
```

### Handling Help

The handling of `-h` or `--help` option and the automatic display of usage
information are taken care by the library. However, if you need to manually
display the help information, there are two functions available: `App.displayHelp()`
and `App.displaySubcommandHelp()`.

- `App.displayHelp()` prints the help information for the root command,
providing a simple way to display the overall usage and description of the
application.

- On the other hand, `App.displaySubcommandHelp()` queries the sepecifed
subcommand on the command line and displays its specific usage information.

```zig
if (!matches.hasArguments()) {
    try app.displayHelp();
    return;
}

if (matches.subcommandMatches("update")) |update_cmd_matches| {
    if (!update_cmd_matches.hasArguments()) {
        try app.displaySubcommandHelp();
        return;
    }
}
```

### Putting it All Together

```zig
const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const log = std.log;
const App = yazap.App;
const Arg = yazap.Arg;

pub fn main() anyerror!void {
    var app = App.init(allocator, "myls", "My custom ls");
    defer app.deinit();

    var myls = app.rootCommand();

    var update_cmd = app.createCommand("update", "Update the app or check for new updates");
    try update_cmd.addArg(Arg.booleanOption("check-only", null, "Only check for new update"));
    try update_cmd.addArg(Arg.singleArgumentOptionWithValidValues("branch", 'b', "Branch to update", &[_][]const u8{
        "stable",
        "nightly",
        "beta"
    }));

    try myls.addSubcommand(update_cmd);

    try myls.addArg(Arg.positional("FILE", null, null));
    try myls.addArg(Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"));
    try myls.addArg(Arg.booleanOption("recursive", 'R', "List subdirectories recursively"));
    try myls.addArg(Arg.booleanOption("one-line", '1', null));
    try myls.addArg(Arg.booleanOption("size", 's', null));
    try myls.addArg(Arg.booleanOption("version", null, null));
    try myls.addArg(Arg.singleArgumentOption("ignore", 'I', null));
    try myls.addArg(Arg.singleArgumentOption("hide", null, null));

    try myls.addArg(Arg.singleArgumentOptionWithValidValues("color", 'C', null, &[_][]const u8{
        "always",
        "auto",
        "never",
    }));

    const matches = try app.parseProcess();
    
    if (!matches.hasArguments()) {
        try app.displayHelp();
        return;
    }

    if (matches.isArgumentPresent("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (matches.getArgumentValue("FILE")) |f| {
        log.info("List contents of {f}");
        return;
    }

    if (matches.subcommandMatches("update")) |update_cmd_matches| {
        if (!update_cmd_matches.hasArguments()) {
            try app.displaySubcommandHelp();
            return;
        }

        if (update_cmd_matches.isArgumentPresent("check-only")) {
            std.log.info("Check and report new update", .{});
            return;
        }
        if (update_cmd_matches.getArgumentValue("branch")) |branch| {
            std.log.info("Branch to update: {s}", .{branch});
            return;
        }
        return;
    }

    if (matches.isArgumentPresent("all")) {
        log.info("show all", .{});
        return;
    }

    if (matches.isArgumentPresent("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (matches.getArgumentValue("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (matches.isArgumentPresent("color")) {
        const when = matches.getArgumentValue("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
```

## Alternate Parsers
- [Hejsil/zig-clap](https://github.com/Hejsil/zig-clap) - Simple command line argument parsing library
- [winksaville/zig-parse-args](https://github.com/winksaville/zig-parse-args) - Parse command line arguments
- [MasterQ32/zig-args](https://github.com/MasterQ32/zig-args) - Simple-to-use argument parser with struct-based config

