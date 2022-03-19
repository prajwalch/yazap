const MatchedFlag = @This();

pub const Arg = union(enum) {
    none: bool,
    single: []const u8,
};

name: []const u8,
arg: Arg,

fn init(name: []const u8) MatchedFlag {
    return MatchedFlag{
        .name = mem.trimLeft(u8, name, "--"),
        .arg = undefined,
    };
}

pub fn initWithoutArg(name: []const u8) MatchedFlag {
    var self = init(name);
    self.arg = .{ .none = true };
    return self;
}

pub fn initWithArg(name: []const u8, arg: []const u8) MatchedFlag {
    var self = init(name);
    self.arg = .{ .single = arg };
    return self;
}
