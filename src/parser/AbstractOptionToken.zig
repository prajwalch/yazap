//! A more detailed view of option token.
//!
//! A normal token only carries the value and type (kind) therefore extracting
//! a much useful information such as option name or value directly from it is
//! not possible.
//!
//! For e.x.: if `-f=value` is a value and `.short_option_with_value` is type
//! then we can't directly extract the name `-f` unless we split the value by
//! `=`.
//!
//! So, for the easy access to the option name and value during parsing, option
//! token is converted into this token.
const AbstractOptionToken = @This();

const std = @import("std");
const Token = @import("../Tokenizer.zig").Token;

/// A view before the `=`.
///
/// It can contain either short and long option name or the short options when
/// they are combined (for e.x.: `-xyz=value`).
before_eq_sign: []const u8,
/// A view after the `=`.
///
/// It can contain the attached value if it's available.
after_eq_sign: ?[]const u8 = null,

/// Converts the given token into this format.
///
/// # Examples
///
/// ## Short options
/// - `-f`             -> `(f, null)`
/// - `-f=`            -> `(f, "")`
/// - `-f=value`       -> `(f, value)`
/// - `-fgh`           -> `(fgh, null)`
/// - `-fgh=`          -> `(fgh, "")`
/// - `-fgh=value`     -> `(fgh, value)`
///
/// ## Long options
/// - `--option`       -> `(option, null)`
/// - `--option=`      -> `(option, "")`
/// - `--option=value` -> `(option, value)`
pub fn from(token: *const Token) AbstractOptionToken {
    var nv_iter = std.mem.tokenizeSequence(u8, token.value, "=");

    return switch (token.kind) {
        .short_option,
        .short_option_with_tail,
        .long_option,
        => .{ .before_eq_sign = token.value },

        .short_option_with_value,
        .short_option_with_empty_value,
        .short_options_with_value,
        .short_options_with_empty_value,
        .long_option_with_value,
        .long_option_with_empty_value,
        => .{ .before_eq_sign = nv_iter.next().?, .after_eq_sign = nv_iter.rest() },

        else => @panic(
            "non-option `Token` cannot be converted into `AbstractOptionToken`",
        ),
    };
}

/// Returns a string slice which can be possibly interpret as option name.
pub fn optionName(self: *const AbstractOptionToken) []const u8 {
    return self.before_eq_sign;
}

/// Returns the option value or returns `null` if it's not present.
pub fn optionAttachedValue(self: *const AbstractOptionToken) ?[]const u8 {
    return self.after_eq_sign;
}
