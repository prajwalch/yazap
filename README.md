# yazap
**yazap** is a command line argument parser for [zig](http://ziglang.org) which provides simple and easy to use API for you to define
custom Argument, flag, subcommand and nested subcommand.

Inspired from [clap-rs](https://github.com/clap-rs/clap) and [andrewrk/ziglang: src-self-hosted/arg.zig](https://git.sr.ht/~andrewrk/ziglang/tree/725b6ee634f01355da4a6badc5675751b85f0bf0/src-self-hosted/arg.zig)

## Features
- Flags
    * boolean/no argument flag (`-f, --flag`)
    * single argument flag (`-f, --flag <VALUE>`)
    * multi argument flag (`-f, --flag <VALUES>`)
        
        Note: You have to explicitly set the number of arguments for it
    
    * single argument flag with options (`-f, --flag <A | B | C>`)

    * Support passing value using space `-f value`
    no space `-fvalue` and using `=` (`-f=value`)

    * Support chaining multiple short flags
        + `-xy` where both `x` and `y` does not take value
        + `-xyz=value`

    * Support for specifying flag multiple times (`-x a -x b -x c`)

- Subcommand
    * `app bool-cmd`
    * `app single-arg-cmd <ARG>`
    * `app multi-arg-cmd <ARG1> <ARG2> <ARGS3...>`
    * `app flag-cmd [flags]`
    * `app arg-and-flag-cmd <ARG> [FLAGS]`
    * Nested subcommand

- Defining custom [Argument](https://prajwalch.github.io/yazap/#root;Arg)
- Auto help text generation


## Installation Guide
Before you follow below steps be sure to initialize your project as repo by running `git init`.
Also note that if you're using zig `v0.10.0` or higher you need to use [v0.10.0 branch](https://github.com/PrajwalCH/yazap/tree/v0.10.0).

1. On your root project make a directory named `libs`
2. Run `git submodule add https://github.com/PrajwalCH/yazap libs/yazap`
3. After above step is complete add the following code snippet on your `build.zig` file
    ```zig
    exe.addPackagePath("yazap", "libs/yazap/src/lib.zig");
    ```
4. Now you can import this library on your src file as
    ```zig
    const yazap = @import("yazap");
    ```
## Docs
Please visit [here](https://prajwalch.github.io/yazap/) for documentation reference

## Example
Checkout [examples/](/examples) for more.

### Initializing the yazap
The first step in using the `yazap` is making an instance of [Yazap](https://prajwalch.github.io/yazap/#root;Yazap)
by calling `Yazap.init(allocator, "Your app name", "Your app description")` or `Yazap.init(allocator, "Your app name", null)` which internally creates a root command for your app.
```zig
var app = Yazap.init(allocator, "myls", "My custom ls");
defer app.deinit();
```

### Getting a root command
[Yazap](https://prajwalch.github.io/yazap/#root;Yazap) itself don't provides an any methods to add arguments for your command.
Its only purpose is to initialize the library, invkoing parser and deinitilize all the structures therefore you must have to use
root command to add arguments and subcommands. You can simply get it by calling `Yazap.rootCommand` which returns a pointer to it.
```zig
var myls = app.rootCommand();
```

### Adding arguments
After you get the root command it's time to add argument by using an appropriate methods provided by `Command`.
See [Command](https://prajwalch.github.io/yazap/#root;Command) to see all the available API.
```zig
try myls.addArg(flag.boolean("all", 'a', "Don't ignore the hidden directories"));
try myls.addArg(flag.boolean("recursive", 'R', "List subdirectories recursively"));

// For now short name can be null but not long name
// that's why one-line long name is used for -1 short name
try myls.addArg(flag.boolean("one-line", '1', null));
try myls.addArg(flag.boolean("size", 's', null));
try myls.addArg(flag.boolean("version", null, null));

try myls.addArg(flag.argOne("ignore", 'I', null));
try myls.addArg(flag.argOne("hide", null, null));

try myls.addArg(flag.option("color", 'C', &[_][]const u8{
    "always",
    "auto",
    "never",
}, null));
```

Here we also use the [flag](https://prajwalch.github.io/yazap/#root;flag) module which is a wrapper around
[Arg](https://prajwalch.github.io/yazap/#root;Arg). It  provides a few different functions for defining
different kind of flags quickly and easily.

### Adding subcommands
You can use `Yazap.createCommand("name", "Subcommand description")` or `Yazap.createCommand("name", null)` to create a subcommand with previously given allocator instead of manually using `Command.new(allocator, "name")` by passing the same allocator twice.
Once you create a subcommand you can add its own arguments and subcommands just like root command.
```zig
var update_cmd = app.createCommand("update", "Update the app or check for new updates");
try update_cmd.addArg(flag.boolean("check-only", null, "Only check for new update"));
try update_cmd.addArg(flag.option("branch", 'b', &[_][]const u8{ "stable", "nightly", "beta" }, "Branch to update"));

try myls.addSubcommand(update_cmd);
```

### Parsing arguments
Once you're done adding arguments and subcommands call `app.parseProcess` to starts parsing. It internally calls [std.process.argsAlloc](https://ziglang.org/documentation/master/std/#root;process.argsAlloc)
to obtain the raw arguments then it invokes the parser and later returns the constant pointer to a [ArgsContext](https://prajwalch.github.io/yazap/#root;ArgsContext). Alternately you can make a call to `app.parseFrom`
by passing your own raw arguments which can be useful on test.
```zig
var ls_args = try app.parseProcess();

if (ls_args.isPresent("version")) {
    log.info("v0.1.0", .{});
    return;
}

if (ls_args.subcommandContext("update")) |update_cmd_args| {
    if (update_cmd_args.isPresent("check-only")) {
        std.log.info("Check and report new update", .{});
        return;
    }

    if (update_cmd_args.valueOf("branch")) |branch| {
        std.log.info("Branch to update: {s}", .{branch});
        return;
    }
    return;
}

if (ls_args.isPresent("all")) {
    log.info("show all", .{});
    return;
}

if (ls_args.isPresent("recursive")) {
    log.info("show recursive", .{});
    return;
}

if (ls_args.valueOf("ignore")) |pattern| {
    log.info("ignore pattern = {s}", .{pattern});
    return;
}

if (ls_args.isPresent("color")) {
    const when = ls_args.valueOf("color").?;

    log.info("color={s}", .{when});
    return;
}
```

### Handling help
You don't have to manually handle `-h` and `--help` but if you want to display help manually
say like when argument is empty you can use `Yazap.displayHelp` and `Yazap.displaySubcommandHelp`.
```zig
if (!(ls_args.hasArgs())) {
    try app.displayHelp();
    return;
}

if (ls_args.subcommandContext("update")) |update_cmd_args| {
    if (!(update_cmd_args.hasArgs()) {
        try app.displaySubcommandHelp();
        return;
    }
}
```

### Putting it all together
```zig
const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const log = std.log;
const flag = yazap.flag;
const Yazap = yazap.Yazap;

pub fn main() anyerror!void {
    var app = Yazap.init(allocator, "myls", "My custom ls");
    defer app.deinit();

    var myls = app.rootCommand();

    var update_cmd = app.createCommand("update", "Update the app or check for new updates");
    try update_cmd.addArg(flag.boolean("check-only", null, "Only check for new update"));
    try update_cmd.addArg(flag.option("branch", 'b', &[_][]const u8{ "stable", "nightly", "beta" }, "Branch to update"));

    try myls.addSubcommand(update_cmd);

    try myls.addArg(flag.boolean("all", 'a', "Don't ignore the hidden directories"));
    try myls.addArg(flag.boolean("recursive", 'R', "List subdirectories recursively"));

    // For now short name can be null but not long name
    // that's why one-line long name is used for -1 short name
    try myls.addArg(flag.boolean("one-line", '1', null));
    try myls.addArg(flag.boolean("size", 's', null));
    try myls.addArg(flag.boolean("version", null, null));

    try myls.addArg(flag.argOne("ignore", 'I', null));
    try myls.addArg(flag.argOne("hide", null, null));

    try myls.addArg(flag.option("color", 'C', &[_][]const u8{
        "always",
        "auto",
        "never",
    }, null));

    var ls_args = try app.parseProcess();

    if (!(ls_args.hasArgs())) {
        try app.displayHelp();
        return;
    }

    if (ls_args.isPresent("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (ls_args.subcommandContext("update")) |update_cmd_args| {
        if (!(update_cmd_args.hasArgs())) {
            try app.displaySubcommandHelp();
            return;
        }

        if (update_cmd_args.isPresent("check-only")) {
            std.log.info("Check and report new update", .{});
            return;
        }
        if (update_cmd_args.valueOf("branch")) |branch| {
            std.log.info("Branch to update: {s}", .{branch});
            return;
        }
        return;
    }

    if (ls_args.isPresent("all")) {
        log.info("show all", .{});
        return;
    }

    if (ls_args.isPresent("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (ls_args.valueOf("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (ls_args.isPresent("color")) {
        const when = ls_args.valueOf("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
```

## Alternate Parsers
- [Hejsil/zig-clap](https://github.com/Hejsil/zig-clap) - Simple command line argument parsing library
- [winksaville/zig-parse-args](https://github.com/winksaville/zig-parse-args) - Parse command line arguments
- [MasterQ32/zig-args](https://github.com/MasterQ32/zig-args) - Simple-to-use argument parser with struct-based config

