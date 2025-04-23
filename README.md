[![test](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml)
[![pages-build-deployment](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment)

# Yazap

> [!NOTE]
> This branch targets the [master branch of zig](https://github.com/ziglang/zig).
> See [supported versions table](#supported-versions-table).

The ultimate [zig](https://ziglang.org) library for seamless command-line parsing.
Effortlessly handles options, subcommands, and custom arguments with ease.

Inspired by [clap-rs](https://github.com/clap-rs/clap) and [andrewrk/ziglang: src-self-hosted/arg.zig](https://git.sr.ht/~andrewrk/ziglang/tree/725b6ee634f01355da4a6badc5675751b85f0bf0/src-self-hosted/arg.zig)

## Supported versions table
| yazap                                                             | Zig                                      |
| ----------------------------------------------------------------- | ---------------------------------------- |
| main                                                              | [master](https://github.com/ziglang/zig) |
| [`0.6.3`](https://github.com/prajwalch/yazap/releases/tag/v0.6.3) | `0.14.0`         |
| [`0.5.1`](https://github.com/prajwalch/yazap/releases/tag/v0.5.1) | `0.12.0`, `0.12.1` and  `0.13.0`         |
| <= `0.5.0`                                                        | Not supported to any                     |

## Key Features:

- [**Options (short and long)**](#adding-arguments):
  - Providing values with `=`, space, or no space (`-f=value`, `-f value`, `-fvalue`).
  - Supports delimiter-separated values with `=` or without space (`-f=v1,v2,v3`, `-fv1:v2:v3`).
  - Chaining multiple short boolean options (`-abc`).
  - Providing values and delimiter-separated values for multiple chained options using `=` (`-abc=val`, `-abc=v1,v2,v3`).
  - Specifying an option multiple times (`-a 1 -a 2 -a 3`).

- [**Positional arguments**](#adding-arguments):
  - Supports positional arguments alongside options for more flexible command-line inputs. For example:
    - `command <positional_arg>`
    - `command <arg1> <arg2> <arg3>`

- [**Nested subcommands**](#adding-subcommands):
  - Organize commands with nested subcommands for a structured command-line interface. For example:
    - `command subcommand`
    - `command subcommand subsubcommand`

- [**Automatic help handling and generation**](#handling-help)

- **Custom Argument definition**:
  - Define custom [Argument](/src/Arg.zig) types for specific application requirements.

## Limitations:

- Does not support delimiter-separated values using space (`-f v1,v2,v3`).
- Does not support providing value and delimiter-separated values for multiple
chained options using space (`-abc value, -abc v1,v2,v3`).

## Installing

1. Run the following command:

```
zig fetch --save git+https://github.com/prajwalch/yazap
```

2. Add the following to `build.zig`:

```zig
const yazap = b.dependency("yazap", .{});
exe.root_module.addImport("yazap", yazap.module("yazap"));
```

## Documentation

For detailed and comprehensive documentation, please visit
[this link](https://prajwalch.github.io/yazap/).

> [!WARNING]
> The documentation site is currently broken, in the meantime check out the source code.

## Usage

### Initializing Yazap

To begin using `yazap`, the first step is to create an instance of 
[App](/src/App.zig) by calling
`App.init(allocator, "Your app name", "optional description")`. This function
internally creates a root command for your application.

```zig
var app = App.init(allocator, "myls", "My custom ls");
defer app.deinit();
```

### Obtaining the Root Command

The [App](/src/App.zig) itself does not provide
any methods for adding arguments to your command. Its main purpose is to
initialize the library, to invoke the parser with necessary arguments, and to
deinitilize the library. 

To add arguments and subcommands, acquire the root command by calling `App.rootCommand()`.
This gives you access to the core command of your application by returning a pointer to it.

```zig
var myls = app.rootCommand();
```

### Adding Arguments

Once you have obtained the root command, you can proceed to add arguments and
[subcommands](#adding-subcommands) using the methods available in the `Command`. For a complete list
of available methods, refer to the [Command API](/src/Command.zig)
documentation.

```zig
try myls.addArg(Arg.positional("FILE", null, null));
try myls.addArg(Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"));
try myls.addArg(Arg.booleanOption("recursive", 'R', "List subdirectories recursively"));
try myls.addArg(Arg.booleanOption("one-line", '1', null));
try myls.addArg(Arg.booleanOption("size", 's', null));
try myls.addArg(Arg.booleanOption("version", null, null));

try myls.addArg(Arg.singleValueOption("ignore", 'I', null));
try myls.addArg(Arg.singleValueOption("hide", null, null));

try myls.addArg(Arg.singleValueOptionWithValidValues(
    "color",
    'C',
    "Colorize the output",
    &[_][]const u8{ "always", "auto", "never" }
));
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

    Arg.singleValueOption("ignore", 'I', null),
    Arg.singleValueOption("hide", null, null),

    Arg.singleValueOptionWithValidValues(
        "color",
        'C',
        "Colorize the output",
        &[_][]const u8{ "always", "auto", "never" }
    ),
});
```

Note that for any option that accepts value, you can set its value placeholder to display in the
help message. If you don't set the placeholder, the option name will be displayed by default.

```zig
var ignore_opt = Arg.singleValueOption("ignore", 'I', null);
ignore_opt.setValuePlaceholder("PATTERN");

var hide_opt = Arg.singleValueOption("hide", null, null);
hide_opt.setValuesPlaceholder("PATTERN");

var color_opt = Arg.singleValueOptionWithValidValues(
    "color",
    'C',
    "Colorize the output",
    &[_][]const u8{ "always", "auto", "never" }
);
color_opt.setValuePlaceholder("WHEN");

try myls.addArgs(&[_]Arg{ ignore_opt, hide_opt, color_opt });
```

### Adding Subcommands

To create a subcommand, use `App.createCommand("name", "optional description")` then
you can add its own arguments and subcommands just like the root command. After you
finish adding arguments, add it as a root subcommand by calling `Command.addSubcommand()`.

```zig
var update_cmd = app.createCommand("update", "Update the app or check for new updates");
try update_cmd.addArg(Arg.booleanOption("check-only", null, "Only check for new update"));
try update_cmd.addArg(Arg.singleValueOptionWithValidValues(
    "branch",
    'b',
    "Branch to update",
    &[_][]const u8{ "stable", "nightly", "beta" }
));

try myls.addSubcommand(update_cmd);
```

### Parsing Arguments

Once you have finished adding all the arguments and subcommands, call `App.parseProcess()`
to start parsing the arguments given to the current process. This function internally utilizes
[`std.process.argsAlloc`](https://ziglang.org/documentation/master/std/#A;std:process.argsAlloc)
to obtain the raw arguments. Alternatively, you can use `App.parseFrom()` and pass your own raw 
arguments, which can be useful during testing. Both functions returns
[`ArgMatches`](/src/ArgMatches.zig).

```zig
const matches = try app.parseProcess();

if (matches.containsArg("version")) {
    log.info("v0.1.0", .{});
    return;
}

if (matches.getSingleValue("FILE")) |f| {
    log.info("List contents of {f}");
    return;
}

if (matches.subcommandMatches("update")) |update_cmd_matches| {
    if (update_cmd_matches.containsArg("check-only")) {
        std.log.info("Check and report new update", .{});
        return;
    }

    if (update_cmd_matches.getSingleValue("branch")) |branch| {
        std.log.info("Branch to update: {s}", .{branch});
        return;
    }
    return;
}

if (matches.containsArg("all")) {
    log.info("show all", .{});
    return;
}

if (matches.containsArg("recursive")) {
    log.info("show recursive", .{});
    return;
}

if (matches.getSingleValue("ignore")) |pattern| {
    log.info("ignore pattern = {s}", .{pattern});
    return;
}

if (matches.containsArg("color")) {
    const when = matches.getSingleValue("color").?;

    log.info("color={s}", .{when});
    return;
}
```

### Handling Help

`-h` and `--h` flag is globally available to all the commands and subcommands and 
handled automatically when they are passed to command line. However, if you need to
manually display the help message there are currently two ways to do it.

#### 1. By invoking `App.displayHelp()` and `App.displaySubcommandHelp()`.

`App.displayHelp()` displays the help message for the root command and
other hand `App.displaySubcommandHelp()` displays the help message for the
active subcommand.

For e.x.: if `gh auth login` were passed then `App.displayHelp()` would display the
help for `gh` and `App.displaySubcommandHelp()` display the help for `login`.

Example:

```zig
if (!matches.containsArgs()) {
    try app.displayHelp();
    return;
}

if (matches.subcommandMatches("update")) |update_cmd_matches| {
    if (!update_cmd_matches.containsArgs()) {
        try app.displaySubcommandHelp();
        return;
    }
}
```

#### 2. By setting `.help_on_empty_args` property to the command.

The `.help_on_empty_args` property which when set to a command, it instructs
the handler to display the help message for that particular command when arguments
are not provided. It behaves exactly like the code shown at the example above.

Example:

```zig
var app = App.init(allocator, "myls", "My custom ls");
defer app.deinit();

var myls = app.rootCommand();
myls.setProperty(.help_on_empty_args);

var update_cmd = app.createCommand("update", "Update the app or check for new updates");
update_cmd.setProperty(.help_on_empty_args);

try myls.addSubcommand(update_cmd);

const matches = try myls.parseProcess();

// --snip--
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
    myls.setProperty(.help_on_empty_args);
    
    try myls.addArgs(&[_]Arg {
        Arg.positional("FILE", null, null),
        Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"),
        Arg.booleanOption("recursive", 'R', "List subdirectories recursively"),
        Arg.booleanOption("one-line", '1', null),
        Arg.booleanOption("size", 's', null),
        Arg.booleanOption("version", null, null),
    });
    
    var ignore_opt = Arg.singleValueOption("ignore", 'I', null);
    ignore_opt.setValuePlaceholder("PATTERN");

    var hide_opt = Arg.singleValueOption("hide", null, null);
    hide_opt.setValuesPlaceholder("PATTERN");

    var color_opt = Arg.singleValueOptionWithValidValues(
        "color",
        'C',
        "Colorize the output",
        &[_][]const u8{ "always", "auto", "never" }
    );
    color_opt.setValuePlaceholder("WHEN");

    try myls.addArgs(&[_]Arg{ ignore_opt, hide_opt, color_opt });

    // Update subcommand.
    var update_cmd = app.createCommand("update", "Update the app or check for new updates");
    update_cmd.setProperty(.help_on_empty_args);

    try update_cmd.addArg(Arg.booleanOption("check-only", null, "Only check for new update"));
    try update_cmd.addArg(Arg.singleValueOptionWithValidValues(
        "branch",
        'b',
        "Branch to update",
        &[_][]const u8{ "stable", "nightly", "beta" }
    ));

    try myls.addSubcommand(update_cmd);

    // Get the parse result.
    const matches = try app.parseProcess();

    if (matches.containsArg("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (matches.getSingleValue("FILE")) |f| {
        log.info("List contents of {f}");
        return;
    }

    if (matches.subcommandMatches("update")) |update_cmd_matches| {
        if (update_cmd_matches.containsArg("check-only")) {
            std.log.info("Check and report new update", .{});
            return;
        }

        if (update_cmd_matches.getSingleValue("branch")) |branch| {
            std.log.info("Branch to update: {s}", .{branch});
            return;
        }
        return;
    }

    if (matches.containsArg("all")) {
        log.info("show all", .{});
        return;
    }

    if (matches.containsArg("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (matches.getSingleValue("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (matches.containsArg("color")) {
        const when = matches.getSingleValue("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
```

## Alternate Parsers
- [Hejsil/zig-clap](https://github.com/Hejsil/zig-clap) - Simple command line argument parsing library
- [winksaville/zig-parse-args](https://github.com/winksaville/zig-parse-args) - Parse command line arguments
- [MasterQ32/zig-args](https://github.com/MasterQ32/zig-args) - Simple-to-use argument parser with struct-based config

