const Tokenizer = @This();

const std = @import("std");
const mem = std.mem;

/// Buffer containing command line arguments.
argv: []const [:0]const u8,
/// Current buffer index.
cursor: usize = 0,

/// Initilizes the tokenizer with the given arguments buffer.
pub fn init(argv: []const [:0]const u8) Tokenizer {
    return Tokenizer{ .argv = argv };
}

/// Returns the next token from the `argv` or returns `null` if tokenizer is ended.
pub fn nextToken(self: *Tokenizer) ?Token {
    // Get the next non-empty argument.
    const arg = while (self.nextRawArg()) |arg| {
        if (arg.len >= 1) {
            break arg;
        }
    } else {
        // Tokenizer ended.
        return null;
    };

    if (mem.startsWith(u8, arg, "--")) {
        return tokenizeLongOption(arg);
    } else if (mem.startsWith(u8, arg, "-")) {
        return tokenizeShortOption(arg);
    }
    return Token.init(arg, .some_argument);
}

/// Returns the next argument as-is.
pub fn nextRawArg(self: *Tokenizer) ?[]const u8 {
    if (self.cursor >= self.argv.len) return null;
    defer self.cursor += 1;

    return @as([]const u8, self.argv[self.cursor]);
}

/// Returns the next argument if it's not an option (i.e. doesn't start with
/// `-` or `--`); otherwise returns `null`.
pub fn nextNonOptionArg(self: *Tokenizer) ?[]const u8 {
    var next_token = self.nextToken() orelse return null;

    if (next_token.isShortOption() or next_token.isLongOption()) {
        self.cursor -= 1;
        return null;
    }
    return next_token.value;
}

/// Returns the remaining args left to tokenize.
pub fn remainingArgs(self: *Tokenizer) ?[]const [:0]const u8 {
    if (self.cursor >= self.argv.len) return null;
    defer self.cursor = self.argv.len;

    return self.argv[self.cursor..];
}

/// Represents an argument token.
pub const Token = struct {
    /// Represents what kind of token is.
    pub const Kind = enum {
        /// `-f`
        short_option,
        /// `-f=value`
        short_option_with_value,
        /// `-f=`
        short_option_with_empty_value,
        /// `-fvalue` or `-fgh`
        short_option_with_tail,
        /// `-fgh=value`
        short_options_with_value,
        /// `-fgh=`
        short_options_with_empty_value,
        /// `--option`
        long_option,
        /// `--option=value`
        long_option_with_value,
        /// `--option=`
        long_option_with_empty_value,
        /// `arg`
        some_argument,
    };
    /// Value of token from the `argv`.
    value: []const u8,
    /// Type of token.
    kind: Kind,

    pub fn init(value: []const u8, kind: Kind) Token {
        return Token{ .value = value, .kind = kind };
    }

    pub fn isShortOption(self: *const Token) bool {
        // zig fmt: off
        return (
            self.kind == .short_option
            or self.kind == .short_option_with_value
            or self.kind == .short_option_with_empty_value
            or self.kind == .short_option_with_tail
            or self.kind == .short_options_with_value
            or self.kind == .short_options_with_empty_value
        );
        // zig fmt: on
    }

    pub fn isLongOption(self: *const Token) bool {
        // zig fmt: off
        return (
            self.kind == .long_option
            or self.kind == .long_option_with_value
            or self.kind == .long_option_with_empty_value
        );
        // zig fmt: on
    }
};

fn tokenizeLongOption(arg: []const u8) Token {
    const option = mem.trimLeft(u8, arg, "--");
    const kind: Token.Kind = blk: {
        if (mem.indexOfScalar(u8, option, '=')) |eql_pos| {
            const has_value = option[eql_pos + 1 ..].len >= 1;

            if (has_value) {
                break :blk .long_option_with_value;
            } else {
                break :blk .long_option_with_empty_value;
            }
        }
        break :blk .long_option;
    };

    return Token.init(option, kind);
}

fn tokenizeShortOption(arg: []const u8) Token {
    const option = mem.trimLeft(u8, arg, "-");
    const kind: Token.Kind = kind: {
        if (mem.indexOfScalar(u8, option, '=')) |eql_pos| {
            const has_options_combined = option[0..eql_pos].len > 1;
            const has_value = option[eql_pos + 1 ..].len >= 1;

            if (has_options_combined) {
                if (has_value) {
                    break :kind .short_options_with_value;
                } else {
                    break :kind .short_options_with_empty_value;
                }
            } else {
                if (has_value) {
                    break :kind .short_option_with_value;
                } else {
                    break :kind .short_option_with_empty_value;
                }
            }
        } else {
            // has tail?
            // for e.x.: -fgh or -fvalue
            if (option.len > 1) break :kind .short_option_with_tail;
        }
        break :kind .short_option;
    };

    return Token.init(option, kind);
}

fn expectToken(actual_token: Token, expected_tag: Token.Kind) !void {
    std.testing.expect(actual_token.kind == expected_tag) catch |e| {
        std.debug.print("\nexpected '{s}', found '{s}'\n", .{
            @tagName(expected_tag), @tagName(actual_token.kind),
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
        "--option",
        "--optioni=value",
        "--option=",
        "arg",
        "",
    };

    var tokenizer = Tokenizer.init(args);

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
