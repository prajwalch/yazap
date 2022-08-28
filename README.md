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


## Installation Guide
Before you follow below steps be sure to initialize your project as repo by running `git init`

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
```zig
const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const log = std.log;
const Command = yazap.Command;
const flag = yazap.flag;

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

