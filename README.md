# zig-arg
zig-arg is a [clap-rs](https://github.com/clap-rs/clap) inspired command line argument parser library for [zig](https://ziglang.org).

It supports flag, subcommand, nested subcommands and has a flexible and easy to use API for defining custom [Argument](#arg).

### Note
zig-arg is still in early development compared to [other parsers](#alternate-parsers).

## Features
* [x] Short flags
    - `-b`, `-1 value`, `-o <a | b | c>`

* [x] Long flag
    - `--bool`
    - `--arg 1, --arg 1 2 `
    - `--option <a | b | c>`

* [x] Support passing flag value using space `-f value`
    no space `-fvalue` and using `=` (`-f=value`)

* [x] Support chaining multiple short flags
    - `-xy` where both `x` and `y` does not take value
    - `-xyz=value`

    Note: Currently if you provided a value for chained flags using space (`-xyz arg`)
    where all of them takes value it will be not parse as you expect. Which means it will
    not take `arg` as a value for `xyz` flags instead it will take `yz` as value for `x`
    even if you pass them as a flags and the `arg` will be parsed a argument or subcommand.

* [x] Support flag that can specified multiple times `-x 1 -x 2 -x 3`

* [x] Subcommand
    - `app bool-cmd`
    - `app single-arg-cmd <ARG>`
    - `app multi-arg-cmd <ARG1> <ARG2> <ARGS3...>`
    - `app flag-cmd [flags]`
    - `app arg-and-flag-cmd <ARG> [FLAGS]`

* [x] Nested subcommand
    - `app cmd1 cmd1.1`


## Installation Guide
Before you follow below steps be sure to initialize your project as repo by running `git init`

1. On your root project make a directory named `libs`
2. Run `git submodule add https://github.com/PrajwalCH/zig-arg libs/zig-arg`
3. After above step is complete add the following code snippet on your `build.zig` file
    ```zig
    exe.addPackagePath("zig-arg", "libs/zig-arg/src/lib.zig");
    ```
4. Now you can import this library on your src file as
    ```zig
    const zig_arg = @import("zig-arg");
    ```

## Docs
Please visit [here](https://prajwalch.github.io/zig-arg/) for documentation reference

## Examples
### Simple ls program
```zig
const std = @import("std");
const zig_arg = @import("zig-arg");

const log = std.log;
const Command = zig_arg.Command;
const flag = zig_arg.flag;

pub fn main() anyerror!void {
    var ls = Command.new(allocator, "ls");
    defer ls.deinit();

    try ls.addArg(flag.boolean("all", 'a'));
    try ls.addArg(flag.boolean("recursive", 'R'));
    // For now short name can be null but not long name
    // that's why one-line long name is used for -1 short name
    try ls.addArg(flag.boolean("one-line", '1'));
    try ls.addArg(flag.boolean("size", 's'));
    try ls.addArg(flag.boolean("version", null));
    try ls.addArg(flag.boolean("help", null));

    try ls.addArg(flag.argOne("ignore", 'I'));
    try ls.addArg(flag.argOne("hide", null));

    try ls.addArg(flag.option("color", 'C', &[_][]const u8{
        "always",
        "auto",
        "never",
    }));

    var ls_args = try ls.parseProcess();
    defer ls_args.deinit();

    // It's upto you how you check for each args
    // for now i am showing you in a straightforward way

    if (ls_args.isPresent("help")) {
       log.info("show help", .{});
       return;
    }

    if (ls_args.isPresent("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (ls_args.isPresent("all")) {
        log.info("show all");
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

