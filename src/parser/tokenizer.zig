const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    pub const Tag = enum {
        // -f
        short_option,
        // -f=value
        short_option_with_value,
        // -f=
        short_option_with_empty_value,
        // -fvalue or -fgh
        short_option_with_tail,
        // -fgh=value
        short_options_with_value,
        // -fgh=
        short_options_with_empty_value,
        // --flag
        long_option,
        // --flag=value
        long_option_with_value,
        // --flag=
        long_option_with_empty_value,
        // -h, --help
        help_option,
        // arg
        some_argument,
    };

    value: []const u8,
    tag: Tag,

    pub fn init(value: []const u8, tag: Tag) Token {
        return Token{ .value = value, .tag = tag };
    }

    pub fn isShortFlag(self: *const Token) bool {
        // zig fmt: off
        return (
            self.tag == .short_option
            or self.tag == .short_option_with_value
            or self.tag == .short_option_with_empty_value
            or self.tag == .short_option_with_tail
            or self.tag == .short_options_with_value
            or self.tag == .short_options_with_empty_value
        );
        // zig fmt: on
    }

    pub fn isLongFlag(self: *const Token) bool {
        // zig fmt: off
        return (
            self.tag == .long_option
            or self.tag == .long_option_with_value
            or self.tag == .long_option_with_empty_value
        );
        // zig fmt: on
    }

    pub fn isHelpFlag(self: *const Token) bool {
        return (self.tag == .help_option);
    }
};

pub const Tokenizer = struct {
    args: []const [:0]const u8,
    cursor: usize,

    pub fn init(args: []const [:0]const u8) Tokenizer {
        return Tokenizer{ .args = args, .cursor = 0 };
    }

    pub fn nextToken(self: *Tokenizer) ?Token {
        var arg = self.nextRawArg() orelse return null;

        if (arg.len == 0) {
            while (self.nextRawArg()) |a| {
                if (a.len >= 1) {
                    arg = a;
                    break;
                }
            } else {
                return null;
            }
        }

        if (mem.startsWith(u8, arg, "--")) {
            return processLongFlag(arg);
        } else if (mem.startsWith(u8, arg, "-")) {
            return processShortFlag(arg);
        }

        return Token.init(arg, .some_argument);
    }

    /// Returns the next raw argument without converting it to token
    pub fn nextRawArg(self: *Tokenizer) ?[]const u8 {
        if (self.cursor >= self.args.len) return null;
        defer self.cursor += 1;

        return @as([]const u8, self.args[self.cursor]);
    }

    /// Returns the next non flag argument
    pub fn nextNonFlagArg(self: *Tokenizer) ?[]const u8 {
        var next_token = self.nextToken() orelse return null;

        if (next_token.isShortFlag() or next_token.isLongFlag() or next_token.isHelpFlag()) {
            self.cursor -= 1;
            return null;
        }

        return next_token.value;
    }

    pub fn restArg(self: *Tokenizer) ?[]const [:0]const u8 {
        if (self.cursor >= self.args.len) return null;
        defer self.cursor = self.args.len;

        return self.args[self.cursor..];
    }

    fn processLongFlag(arg: []const u8) Token {
        const flag = mem.trimLeft(u8, arg, "--");
        const tag: Token.Tag = blk: {
            // Check for 'help' flag
            if (std.mem.eql(u8, flag, "help"))
                break :blk .help_option;

            if (mem.indexOfScalar(u8, flag, '=')) |eql_pos| {
                const has_value = (eql_pos + 1) < flag.len;

                if (has_value) {
                    break :blk .long_option_with_value;
                } else {
                    break :blk .long_option_with_empty_value;
                }
            }
            break :blk .long_option;
        };

        return Token.init(flag, tag);
    }

    fn processShortFlag(arg: []const u8) Token {
        const flag = mem.trimLeft(u8, arg, "-");
        const tag: Token.Tag = blk: {
            // Check for 'h' flag
            if (std.mem.eql(u8, flag, "h"))
                break :blk .help_option;

            if (mem.indexOfScalar(u8, flag, '=')) |eql_pos| {
                const is_options = (flag[0..eql_pos]).len > 1;
                const has_value = (eql_pos + 1) < flag.len;

                if (is_options) {
                    if (has_value) {
                        break :blk .short_options_with_value;
                    } else {
                        break :blk .short_options_with_empty_value;
                    }
                } else {
                    if (has_value) {
                        break :blk .short_option_with_value;
                    } else {
                        break :blk .short_option_with_empty_value;
                    }
                }
            } else {
                // has tail?
                // for ex: -fgh or -fvalue
                if (flag.len > 1) break :blk .short_option_with_tail;
            }
            break :blk .short_option;
        };

        return Token.init(flag, tag);
    }
};

fn expectToken(actual_token: Token, expected_tag: Token.Tag) !void {
    std.testing.expect(actual_token.tag == expected_tag) catch |e| {
        std.debug.print("\nexpected '{s}', found '{s}'\n", .{
            @tagName(expected_tag), @tagName(actual_token.tag),
        });
        return e;
    };
}

test "tokenizer" {
    const args = &.{
        "-h",
        "-f",
        "-f=val",
        "-f=",
        "-fgh",
        "-fgh=value",
        "-fgh=",
        "",
        "",
        "--flag",
        "--flagi=value",
        "--flag=",
        "arg",
        "",
    };

    var tokenizer = Tokenizer.init(args);

    try expectToken(tokenizer.nextToken().?, .help_option);
    try expectToken(tokenizer.nextToken().?, .short_option);
    try expectToken(tokenizer.nextToken().?, .short_option_with_value);
    try expectToken(tokenizer.nextToken().?, .short_option_with_empty_value);
    try expectToken(tokenizer.nextToken().?, .short_option_with_tail);
    try expectToken(tokenizer.nextToken().?, .short_options_with_value);
    try expectToken(tokenizer.nextToken().?, .short_options_with_empty_value);

    try expectToken(tokenizer.nextToken().?, .long_option);
    try expectToken(tokenizer.nextToken().?, .long_option_with_value);
    try expectToken(tokenizer.nextToken().?, .long_option_with_empty_value);

    try expectToken(tokenizer.nextToken().?, .some_argument);
}
