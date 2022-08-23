# Command
Making instance of it by calling `Command.new(allocator, "You app name")` is the first step you have to do.

Then add the custom [Argument](#arg), [flag](#flag) and sub-command by using the provided methods.
Once you're done adding all, call `Command.parseProcess` to start parsing the
raw argument which internally calls `[std.process.argsAlloc](https://ziglang.org/documentation/master/std/#root;process.argsAlloc)` to
obtain the arguments. Alternately you can call `Command.parseFrom` by passing your own argument.

## Methods
### fn addArgs
```zig
fn addArg(self: *Command, new_arg: Arg) !void
```

### fn addSubcommand 
```zig
fn addSubcommand(self: *Command, new_subcommand: Command) !void
```

### fn takesSingleValue
```zig
fn takesSingleValue(self: *Command arg_name: []const u8) !void
```
Creates an [Argument]() with given name and specifies that command will take a single value.

### fn takesNValues
```zig
fn takesNValues(self: *Command, arg_name: []constu8, n: usize) !void
```
Creates an [Argument](#arg) with given name and specifies that command will take `n` values.

### fn argRequired
```zig
fn argRequired(self: *Command, b: bool) void
```
Specifies that argument is required to provide. Default to `false`

### fn subcommandRequired
```zig
fn subcommandRequired(self: *Command, b: bool) void
```
Specifies that sub-command is required to provide. Default to `false`

### fn countArgs
```zig
fn countArgs(self: *const Command) usize
```

### fn countSubcommands
```zig
fn countSubcommands(self: *const Command) usize
```

### fn findArgByShortName
```zig
fn findArgByShortName(self: *const Command, short_name: u8) ?*const Arg
```
Linearly searches for an argument with short name equals to given `short_name`.
Returns a const pointer of a found argument otherwise null.

### fn findArgByLongName
```zig
fn findArgByLongName(self: *const Command, long_name: []const u8) ?*const Arg
```
Linearly searches for an argument with long name equals to given `long_name`.
Returns a const pointer of a found argument otherwise null.

### fn findSubcommand
```zig
fn findSubcommand(self: *const Command, subcmd_name: []const u8) ?*const Command
```
Linearly searches a sub-command with name equals to given `subcmd_name`.
Returns a const pointer of a found sub-command otherwise null.

### fn parseProcess
```zig
fn parseProcess(self: *Command) Error!ArgsContext
```
Starts parsing the process arguments.

### fn parseFrom
```zig
fn parseFrom(self: *Command, argv: []const [:0]const u8) Error!ArgsContext
```
Starts parsing the given arguments.

## Error
```zig
pub const Error = error{
    InvalidCmdLine,
    Overflow,
} || Parser.Error || ErrorContext.PrintError;
```
