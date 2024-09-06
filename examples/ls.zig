const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const log = std.log;
const App = yazap.App;
const Arg = yazap.Arg;

pub fn main() anyerror!void {
    var app = App.init(allocator, "myls", "My custom ls");
    defer app.deinit();

    var myls = app.rootCommand();

    var update_cmd = app.createCommand("update", "Update the app or check for new updates");
    try update_cmd.addArg(Arg.booleanOption("check-only", null, "Only check for new update"));
    try update_cmd.addArg(Arg.singleValueOptionWithValidValues(
        "branch",
        'b',
        "Branch to update",
        &[_][]const u8{ "stable", "nightly", "beta" },
    ));

    try myls.addSubcommand(update_cmd);

    try myls.addArg(Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"));
    try myls.addArg(Arg.booleanOption("recursive", 'R', "List subdirectories recursively"));
    try myls.addArg(Arg.booleanOption("one-line", '1', "List each entries in new line"));
    try myls.addArg(Arg.booleanOption("size", 's', "Display file size"));
    try myls.addArg(Arg.booleanOption("version", null, "Display program version number"));
    try myls.addArg(Arg.singleValueOption("ignore", 'I', "Ignore the given pattern"));
    try myls.addArg(Arg.singleValueOption("hide", null, "Don't display hidden entries"));
    try myls.addArg(Arg.singleValueOptionWithValidValues(
        "color",
        'C',
        "Enable or disable output color",
        &[_][]const u8{ "always", "auto", "never" },
    ));

    const matches = try app.parseProcess();

    if (!(matches.containsArgs())) {
        try app.displayHelp();
        return;
    }

    if (matches.containsArg("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (matches.subcommandMatches("update")) |update_cmd_matches| {
        if (!(update_cmd_matches.containsArgs())) {
            try app.displaySubcommandHelp();
            return;
        }

        if (update_cmd_matches.containsArg("check-only")) {
            std.log.info("Check and report new update", .{});
            return;
        }
        if (update_cmd_matches.getSingleValue("branch")) |branch| {
            std.log.info("Branch to update: {s}", .{branch});
            return;
        }
        return;
    }

    if (matches.containsArg("all")) {
        log.info("show all", .{});
        return;
    }

    if (matches.containsArg("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (matches.getSingleValue("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (matches.containsArg("color")) {
        const when = matches.getSingleValue("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
