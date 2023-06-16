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
    try update_cmd.addArg(Arg.singleArgumentOptionWithValidValues("branch", 'b', "Branch to update", &[_][]const u8{
        "stable",
        "nightly",
        "beta",
    }));

    try myls.addSubcommand(update_cmd);

    try myls.addArg(Arg.booleanOption("all", 'a', "Don't ignore the hidden directories"));
    try myls.addArg(Arg.booleanOption("recursive", 'R', "List subdirectories recursively"));
    try myls.addArg(Arg.booleanOption("one-line", '1', null));
    try myls.addArg(Arg.booleanOption("size", 's', null));
    try myls.addArg(Arg.booleanOption("version", null, null));
    try myls.addArg(Arg.singleArgumentOption("ignore", 'I', null));
    try myls.addArg(Arg.singleArgumentOption("hide", null, null));
    try myls.addArg(Arg.singleArgumentOptionWithValidValues("color", 'C', null, &[_][]const u8{
        "always",
        "auto",
        "never",
    }));

    const matches = try app.parseProcess();

    if (!(matches.hasArgs())) {
        try app.displayHelp();
        return;
    }

    if (matches.isPresent("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (matches.subcommandMatches("update")) |update_cmd_args| {
        if (!(update_cmd_args.hasArgs())) {
            try app.displaySubcommandHelp();
            return;
        }

        if (update_cmd_args.isPresent("check-only")) {
            std.log.info("Check and report new update", .{});
            return;
        }
        if (update_cmd_args.valueOf("branch")) |branch| {
            std.log.info("Branch to update: {s}", .{branch});
            return;
        }
        return;
    }

    if (matches.isPresent("all")) {
        log.info("show all", .{});
        return;
    }

    if (matches.isPresent("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (matches.valueOf("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (matches.isPresent("color")) {
        const when = matches.valueOf("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
