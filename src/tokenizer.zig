const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    pub const Tag = enum {
        // -f
        short_flag,
        // -f=value
        short_flag_with_value,
        // -f=
        short_flag_with_empty_value,
        // -fvalue or -fgh
        short_flag_with_tail,
        // -fgh=value
        short_flags_with_value,
        // -fgh=
        short_flags_with_empty_value,
        // --flag
        long_flag,
        // --flag=value
        long_flag_with_value,
        // --flag=
        long_flag_with_empty_value,
        // arg
        some_argument,
    };

    value: []const u8,
    tag: Tag,

    pub fn init(value: []const u8, tag: Tag) Token {
        return Token{ .value = value, .tag = tag };
    }

    pub fn isShortFlag(self: *Token) bool {
        // zig fmt: off
        return (
            self.tag == .short_flag
            or self.tag == .short_flag_with_value
            or self.tag == .short_flag_with_empty_value
            or self.tag == .short_flag_with_tail
            or self.tag == .short_flags_with_value
            or self.tag == .short_flags_with_empty_value
        );
        // zig fmt: on
    }

    pub fn isLongFlag(self: *Token) bool {
        // zig fmt: off
        return (
            self.tag == .long_flag
            or self.tag == .long_flag_with_value
            or self.tag == .long_flag_with_empty_value
        );
        // zig fmt: on
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

        if (next_token.isShortFlag() or next_token.isLongFlag()) {
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
        var tag: Token.Tag = .long_flag;

        if (mem.indexOfScalar(u8, flag, '=')) |eql_pos| {
            const has_value = (eql_pos + 1) < flag.len;

            tag = blk: {
                if (has_value) {
                    break :blk .long_flag_with_value;
                } else {
                    break :blk .long_flag_with_empty_value;
                }
            };
        }

        return Token.init(flag, tag);
    }

    fn processShortFlag(arg: []const u8) Token {
        const flag = mem.trimLeft(u8, arg, "-");
        var tag: Token.Tag = .short_flag;

        if (mem.indexOfScalar(u8, flag, '=')) |eql_pos| {
            const is_flags = (flag[0..eql_pos]).len > 1;
            const has_value = (eql_pos + 1) < flag.len;

            if (is_flags) {
                tag = blk: {
                    if (has_value) {
                        break :blk .short_flags_with_value;
                    } else {
                        break :blk .short_flags_with_empty_value;
                    }
                };
            } else {
                tag = blk: {
                    if (has_value) {
                        break :blk .short_flag_with_value;
                    } else {
                        break :blk .short_flag_with_empty_value;
                    }
                };
            }
        } else {
            // has tail?
            // for ex: -fgh or -fvalue
            if (flag.len > 1) tag = .short_flag_with_tail;
        }

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

    try expectToken(tokenizer.nextToken().?, .short_flag);
    try expectToken(tokenizer.nextToken().?, .short_flag_with_value);
    try expectToken(tokenizer.nextToken().?, .short_flag_with_empty_value);
    try expectToken(tokenizer.nextToken().?, .short_flag_with_tail);
    try expectToken(tokenizer.nextToken().?, .short_flags_with_value);
    try expectToken(tokenizer.nextToken().?, .short_flags_with_empty_value);

    try expectToken(tokenizer.nextToken().?, .long_flag);
    try expectToken(tokenizer.nextToken().?, .long_flag_with_value);
    try expectToken(tokenizer.nextToken().?, .long_flag_with_empty_value);

    try expectToken(tokenizer.nextToken().?, .some_argument);
}
