# zig-arg
zig-arg is a [clap-rs](https://github.com/clap-rs/clap) inspired Command Line Argument parser for zig which support flags, subcommand and nested subcommands out of the box.

This library is in active development so many of the features are yet to implement and bugs are expected to happen.

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
    - [ ] `-xzyvalue` 
    - [ ] `-xyz value`
    - [ ] `-xyz=value`

* [ ] Support flag that can specified multiple times `-x 1 -x 2 -x 3`

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

## Examples
### `Flag, Command.takesSingleValue and Command.takesNValues`
These 3 are the thin wrapper of `Arg` which handles necessary options and settings to define how flag, single argument
and multiple arguments should parse respectively. This is the simplest and recommended way to use this library.
See [below](#Arg) to learn more about `Arg`.

```zig
const std = @import("std");
const zig_arg = @import("zig-arg");

const allocator = std.heap.page_allocator;
const Command = zig_arg.Command;
const Flag = zig_arg.Flag;

pub fn main() anyerror!void {
    var app = Command.new(allocator, "app");
    defer app.deinit();

    // app <ARG>
    try app.takesSingleValue("ARG");

    // app [FLAGS]
    try app.addArg(Flag.boolean("--bool-flag"));
    try app.addArg(Flag.argOne("--arg-flag"));

    // app bool-subcmd
    try app.addSubcommand(Command.new(allocator, "bool-subcmd"));

    // app subcmd1 <ARGS...>
    var cmd1 = Command.new(allocator, "subcmd-1");
    try cmd1.takesNValues("ARGS", 3);

    // app subcmd2 <ARG>
    var cmd2 = Command.new(allocator, "subcmd-2");
    try cmd2.takesSingleValue("ARG");

    // app subcmd3 <ARG0> <ARG1>
    var cmd3 = Command.new(allocator, "subcmd-3");
    try cmd3.takesSingleValue("ARG0");
    try cmd3.takesSingleValue("ARG1");

    // app subcmd4 <ARG2> [flags]
    var cmd4 = Command.new(allocator, "subcmd-4");
    try cmd4.takesSingleValue("ARG2");
    try cmd4.addArg(Flag.boolean("--bool-flag"));
    try cmd4.addArg(Flag.argOne("--arg-flag"));
    // app submd4 --opt-flag [opt1, opt2, opt3]
    // parse method will return error.ValueIsNotInAllowedValues if provided value does not match with options
    try cmd4.addArg(Flag.option("--opt-flag", &[_]{
        "opt1",
        "opt2",
    }));

    try app.addSubcommand(cmd1);
    try app.addSubcommand(cmd2);
    try app.addSubcommand(cmd3);
    try app.addSubcommand(cmd4);

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var app_args = try app.parse(argv);
    defer app_args.deinit();

    if (app_args.isPresent("bool-flag")) {
        // logic here
    }

    // You can use isPresent to check any argument whether
    // if it's exist or not before querying it
    if (app_args.isPresent("ARG")) {
        var single_value = app_arg.valueOf("ARG").?;
    }

    if (app_args.valueOf("arg-flag")) |value| {
        // logic here
    }

    if (app_args.isPresent("bool-cmd")) {
        // logic here
    }

    if (app_args.valuesOf("ARGS")) |values| {
        // logic here
    }

    // valueOf recursively search for an argument but if app and subcommand have same argument name 
    // like in this example app and subcmd2 have same ARG argument in that case it will return the value
    // of app ARG because it will tries to find in self.args then it will begin to search in self.subcommand
    // if not found. Therefore to get the value of subcmd2 ARG call subcommandMatches(cmd_name) to get args
    // of cmd_name then you can call valueOf

    if (app_args.subcommandMatches("subcmd-2")) |subcmd2_args| {
        // Here no need call subcm2_args.deinit() because app_args.deinit() will
        // be sufficient

        if (subcmd2_args.valueOf("ARG")) |value| {
            // logic here
        }
    }

   if (app_args.subcommandMatches("subcmd-4")) |subcmd4_args| {
       if (subcmd4_args.isPresent("bool-flag")) {
           // logic here
       }

       if (subcmd4_args.valueOf("arg-flag")) |arg_flag_value|{
           // logic here
       }
   }
}
```

### `Arg`
`Arg` is an abstract representation of argument which has all the options and settings
to define valid argument and to tell parser how it should parse. Let's take a simple example
to learn how you can use `Arg` to define argument for command and subcommand.

```zig
const std = @import("std");
const zig_arg = @import("zig-arg");

const allocator = std.heap.page_allocator;
const Command = zig_arg.Command;
const Arg = zig_arg.Arg;

pub fn main() anyerror!void {
    var app = Command.new(allocator, "app");
    defer app.deinit();

    var app_single_arg = Arg.new("ARG");
    app_single_arg.minValues(1);
    app_single_arg.maxValues(1);
    app_single_arg.allValuesRequired(true);

    var app_many_args = Arg.new("ARGS");
    app_many_args.minValue(1);
    app_many_args.maxValues(5);
    // When set true parse method will return error.IncompleteArgValues if provided values
    // is less then maxValues
    app_many_args.allValuesRequired(true);

    var app_opt_flag = Arg.new("--option-flag");
    // parse method will return error.ValueIsNotInAllowedValues
    // if provided value does not match with any allowed values
    app_opt_flag.allowedValues(&[_]{
        "opt1",
        "opt2",
    });

    try app.addArg(Arg.new("--bool-flag"));
    try app.addArg(app_single_arg);
    try app.addArg(app_many_args);
    try app.addArg(app_opt_flag);

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var app_args = try app.parse(argv);
    defer app_args.deinit();

    // use just like above example
}
```

## Alternate Parsers
- [Hejsil/zig-clap](https://github.com/Hejsil/zig-clap) - Simple command line argument parsing library
- [winksaville/zig-parse-args](https://github.com/winksaville/zig-parse-args) - Parse command line arguments
- [MasterQ32/zig-args](https://github.com/MasterQ32/zig-args) - Simple-to-use argument parser with struct-based config

