[![test](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/PrajwalCH/yazap/actions/workflows/test.yml)
[![pages-build-deployment](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/PrajwalCH/yazap/actions/workflows/pages/pages-build-deployment)

# Yazap
> **Note**
> This branch targets the [master branch of zig](https://github.com/ziglang/zig). Use [v0.9.x-v0.10.x](https://github.com/PrajwalCH/yazap/tree/v0.9.x-v0.10.x) branch if you're using older version of zig

**Yazap** is a simple and easy-to-use [zig](https://ziglang.org) library that is designed for parsing not only flags
but also subcommands, nested subcommands and custom arguments.

Inspired by [clap-rs](https://github.com/clap-rs/clap) and [andrewrk/ziglang: src-self-hosted/arg.zig](https://git.sr.ht/~andrewrk/ziglang/tree/725b6ee634f01355da4a6badc5675751b85f0bf0/src-self-hosted/arg.zig)

## Features:
- Providing comma-seperated values for command (`touch one,two,three`)
- Option (short and long)
    * Providing value using `=`, using space and without using space (`-f=value, -f value, -fvalue`)
    * Providing comma-seperated values using `=` and without using space (`-f=v1,v2,v3, -fv1,v2,v3`)
    * Chaining multiple short boolean options (`-abc`)
    * Providing value and comma-seperated values for multiple chained options using `=` (`-abc=val`, `-abc=v1,v2,v3`)
    * Specifying option multiple times (`-a 1 -a 2 -a 3`)
- Nested subcommands
- Automatic handling help flag (`-h` and `--help`)
- Automatic help generation
- Defining custom [Argument](https://prajwalch.github.io/yazap/#root;Arg)

## What doesn't supports:
- Providing comma-seperated values using space (`-f v1,v2,v3`)
- Providing value and comma-seperated values for multiple chained options using space (`-abc value, -abc v1,v2,v3`)
- Automatic generation of shell completion (in progress)


## Installing
Requires [zig v0.11.x](https://ziglang.org)

1. Initialize your project as repository (if not initialized already) by running `git init`
2. On your root project make a directory named `libs`
3. Run `git submodule add https://github.com/PrajwalCH/yazap libs/yazap`
4. After above step is complete add the following code snippet on your `build.zig` file
    ```zig
    exe.addAnonymousModule("yazap", .{
        .source_file = .{ .path = "libs/yazap/src/lib.zig" },
    });
    ```
5. Now you can import this library on your src file as
    ```zig
    const yazap = @import("yazap");
    ```
## Docs
Visit [here](https://prajwalch.github.io/yazap/) for complete documentation

## Building and running examples
The examples are present [here](/examples) and to build all of them run:
```bash
$ zig build examples
```
Then after the compilation finishes you can run them as:
```bash
$ ./zig-out/bin/example_name
```

## Usage
### Initializing the yazap
The first step in using the `yazap` is making an instance of [App](https://prajwalch.github.io/yazap/#root;App)
by calling `App.init(allocator, "Your app name", "Your app description")` or `App.init(allocator, "Your app name", null)` which internally creates a root command for your app.
```zig
var app = App.init(allocator, "myls", "My custom ls");
defer app.deinit();
```

### Getting a root command
[App](https://prajwalch.github.io/yazap/#root;App) itself don't provides an any methods to add arguments for your command.
Its only purpose is to initialize the library, invkoing parser and deinitilize all the structures therefore you must have to use
root command to add arguments and subcommands. You can simply get it by calling `App.rootCommand` which returns a pointer to it.
```zig
var myls = app.rootCommand();
```

### Adding arguments
After you get the root command you can start to add argument by using an appropriate methods provided by `Command`.
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
You can use `App.createCommand("name", "Subcommand description")` or `App.createCommand("name", null)` to create a subcommand with previously given allocator instead of manually using `Command.new(allocator, "name")` by passing the same allocator twice.
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
const ls_args = try app.parseProcess();

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
Handling `-h` or `--help` and displaying usage is done automatically but if you want to display help
manually when `-h` or `--help` is not present on command line you can call `App.displayHelp` and
`App.displaySubcommandHelp` to display root level help and provided subcommand help respectively.
This is useful in condition like when argument is not provided.
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
const App = yazap.App;

pub fn main() anyerror!void {
    var app = App.init(allocator, "myls", "My custom ls");
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

    const ls_args = try app.parseProcess();

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

