# zig-arg
[clap-rs](https://github.com/clap-rs/clap) inspired arg parser library for zig that supports both subcommand, nested subcommand and flag.

This library is in active development so many of the features are yet to implement and bugs are expected to happen.

## Features Roadmap
* [x] Long Flag
    - `app --bool-flag`
    - `app --arg-flag value`
    - `app --flag-that-takes-multiple-values a1 a2`
* [x] Boolean subcommand (which does not take any argument)
* [x] Subcommand that takes single/multiple arg on a single/multiple placeholder
    - `app cmd <ARGS...>`
    - `app cmd <ARG1> <ARG2>`
    - `app cmd <ARGS1...> <ARGS2...>`
* [x] Subcommand that takes both arg and long flag (same as first point)
    - `app cmd <ARG1> [flags]`
* [x] Nested subcommand (with all the above features)
    - `app cmd1 cmd1`
* [ ] Short flags
* [ ] Support passing short flag value by `= (-f=value)`, space `(-f value)` and without space `(-fvalue)`
* [ ] Support chaining multiple flags `-xyz, -xzyvalue, -xyz value and -xyz=value`
* [ ] Support flag that can specified multiple times `-x 1 -x 2 -x 3`

## Installation Guide
Note: Before you follow below steps be sure to initilize your project as repo by running `git init`

- On your root project make a directory named `libs`
- Run `git submodule add https://github.com/PrajwalCH/zig-arg libs/zig-arg`
- Once above step is complete add the following code on your `build.zig` file
    ```zig
    exe.addPackagePath("zig-arg", "libs/zig-arg/src/lib.zig");
    ```
- After all above steps is complete you can now import `zig-arg` on your source file as
    ```zig
    const zig_arg = @import("zig-arg");
    ```

## Usage
```zig
const std = @import("std");
const zig_arg = @import("zig-arg");

const allocator = std.heap.page_allocator;
const Command = zig_arg.Command;
const Flag = zig_arg.Flag;

pub fn main() anyerror!void {
    var root_cmd = Command.new(allocator, "root-cmd");
    try root_cmd.addSubcommand(Command.new(allocator, "bool-cmd"));

    // cmd subcmd1 <ARGS...>
    var cmd1 = Command.new(allocator, "subcmd-1");
    try cmd1.takesNValues("ARGS", 3);

    // cmd subcmd2 <ARG>
    var cmd2 = Command.new(allocator, "subcmd-2");
    try cmd2.takesSingleValue("ARG");

    // cmd subcmd3 <ARG0> <ARG1>
    var cmd3 = Command.new(allocator, "subcmd-3");
    try cmd3.takesSingleValue("ARG0");
    try cmd3.takesSingleValue("ARG1");

    // cmd subcmd4 <ARG2> [flags]
    var cmd4 = Command.new(allocator, "subcmd-4");
    try cmd4.takesSingleValue("ARG2");
    try cmd4.addArg(Flag.boolean("--bool-flag"));
    try cmd4.addArg(Flag.argOne("--arg-flag"));
    // cmd submd4 --opt-flag [opt1, opt2, opt3]
    // parse method will return error.ValueIsNotInAllowedValues if provided value does not match with options
    try cmd4.addArg(Flag.option("--opt-flag", &[_]{
        "opt1",
        "opt2",
    }));

    try root_cmd.addSubcommand(cmd1);
    try root_cmd.addSubcommand(cmd2);
    try root_cmd.addSubcommand(cmd3);
    try root_cmd.addSubcommand(cmd4);

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var args = try root_cmd.parse(argv);
    defer args.deinit();

    if (args.isPresent("bool-cmd")) {
        // logic here
    }

    // you can also use isPresent to check other args
    if (args.isPresent("ARGS")) {
        // logic here
    }

    // cmd1 args
    if (args.valuesOf("ARGS")) |values| {
        // logic here
    }

    // cmd2 arg
    if (args.valueOf("ARG")) |value| {
        // logic here
    }

   if (args.subcommandMatches("subcmd-4")) |subcmd4_args| {
       if (subcmd4_args.isPresent("bool-flag")) {
           // logic here
       }

       if (subcmd4_args.valueOf("arg-flag")) |arg_flag_value|{
           // logic here
       }
   }
}
```

If you don't like default behavior of `Flag` and `cmd.takesSingleValue() and cmd.takesNValues()` use `Arg` instead.
Basically `Flag` and `cmd.takesSingleValue() and cmd.takesNValues()` are just a wrapper of `Arg` which handles necessary settings and members to parse as a flag and raw value respectively.
Lets take above example but we will use `Arg` to manually to define how arg should parse.

```zig
const std = @import("std");
const zig_arg = @import("zig-arg");

const allocator = std.heap.page_allocator;
const Command = zig_arg.Command;
const Arg = zig_arg.Arg;

pub fn main() anyerror!void {
    var root_cmd = Command.new(allocator, "root-cmd");
    try root_cmd.addSubcommand(Command.new(allocator, "bool-cmd"));

    // cmd subcmd1 <ARGS...>
    var cmd1_arg = Arg.new("ARGS");
    cmd1_arg.minValues(1);
    cmd1_arg.maxValues(3);
    // When set true it will return error.IncompleteArgValues
    // when provided values are less then  maxValues
    cmd1_arg.allValuesRequired(true);
    
    var cmd1 = Command.new(allocator, "subcmd-1");
    try cmd1.addArg(cmd1_arg);

    // cmd subcmd2 <ARG>
    var cmd2_arg = Arg.new("ARG");
    cmd2_arg.minValues(1);
    cmd2_arg.maxValues(1);
    cmd2_arg.allValuesRequired(true);

    var cmd2 = Command.new(allocator, "subcmd-2");
    try cmd2.addArg(cmd2_arg);

    // cmd subcmd3 <ARG0> <ARG1>
    var cmd3_arg0 = Arg.new("ARG0");
    cmd3_arg0.minValues(1);
    cmd3_arg0.maxValues(1);
    cmd3_arg0.allValuesRequired(true);

    var cmd3_arg1 = Arg.new("ARG1");
    cmd3_arg1.minValues(1);
    cmd3_arg1.maxValues(1);
    cmd3_arg1.allValuesRequired(true);

    var cmd3 = Command.new(allocator, "subcmd-3");
    try cmd3.addArg(cmd3_arg0);
    try cmd3.addArg(cmd3_arg1);
    try cmd3.takesSingleValue("ARG1");

    // cmd subcmd4 <ARG2> [flags]
    var cmd4_arg = Arg.new("ARG2");
    cmd4_arg.minValues(1);
    cmd4_arg.maxValues(1);
    cmd4_arg.allValuesRequired(true);

    var cmd4_arg_flag = Arg.new("--arg-flag");
    cmd4_arg_flag.minValues(1);
    cmd4_arg_flag.maxValues(1);
    cmd4_arg_flag.allValuesRequired(true);

    var cmd4_opt_flag = Arg.new(--opt-flag);
    cmd4_opt_flag.minValues(1);
    cmd4_opt_flag.maxValues(1);
    // cmd submd4 --opt-flag [opt1, opt2, opt3]
    // parse method will return error.ValueIsNotInAllowedValues if provided value does not match with options
    cmd4_opt_flag.allowedValues(&[_]{
        "opt1",
        "opt2",
    });

    var cmd4 = Command.new(allocator, "subcmd-4");
    try cmd4.addArg(cmd4_arg);
    try cmd4.addArg(Arg.new("--bool-flag"));
    try cmd4.addArg(cmd4_arg_flag);
    try cmd4.addArg(cmd4_opt_flag);

    try root_cmd.addSubcommand(cmd1);
    try root_cmd.addSubcommand(cmd2);
    try root_cmd.addSubcommand(cmd3);
    try root_cmd.addSubcommand(cmd4);

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var args = try root_cmd.parse(argv);
    defer args.deinit();

    if (args.isPresent("bool-cmd")) {
        // logic here
    }

    // you can also use isPresent to check other args
    if (args.isPresent("ARGS")) {
        // logic here
    }

    // cmd1 args
    if (args.valuesOf("ARGS")) |values| {
        // logic here
    }

    // cmd2 arg
    if (args.valueOf("ARG")) |value| {
        // logic here
    }

   if (args.subcommandMatches("subcmd-4")) |subcmd4_args| {
       if (subcmd4_args.isPresent("bool-flag")) {
           // logic here
       }

       if (subcmd4_args.valueOf("arg-flag")) |arg_flag_value|{
           // logic here
       }
   }
}
```

