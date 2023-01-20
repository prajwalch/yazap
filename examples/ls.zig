const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const log = std.log;
const flag = yazap.flag;
const App = yazap.App;

pub fn main() anyerror!void {
    var app = App.init(allocator, "myls", "My custom ls");
    defer app.deinit();

    var myls = app.rootCommand();

    var update_cmd = app.createCommand("update", "Update the app or check for new updates");
    try update_cmd.addArg(flag.boolean("check-only", null, "Only check for new update"));
    try update_cmd.addArg(flag.option("branch", 'b', &[_][]const u8{ "stable", "nightly", "beta" }, "Branch to update"));

    try myls.addSubcommand(update_cmd);

    try myls.addArg(flag.boolean("all", 'a', "Don't ignore the hidden directories"));
    try myls.addArg(flag.boolean("recursive", 'R', "List subdirectories recursively"));

    // For now short name can be null but not long name
    //     // that's why one-line long name is used for -1 short name
    try myls.addArg(flag.boolean("one-line", '1', null));
    try myls.addArg(flag.boolean("size", 's', null));
    try myls.addArg(flag.boolean("version", null, null));

    try myls.addArg(flag.argOne("ignore", 'I', null));
    try myls.addArg(flag.argOne("hide", null, null));

    try myls.addArg(flag.option("color", 'C', &[_][]const u8{
        "always",
        "auto",
        "never",
    }, null));

    const ls_args = try app.parseProcess();

    if (!(ls_args.hasArgs())) {
        try app.displayHelp();
        return;
    }

    if (ls_args.isPresent("version")) {
        log.info("v0.1.0", .{});
        return;
    }

    if (ls_args.subcommandContext("update")) |update_cmd_args| {
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

    if (ls_args.isPresent("all")) {
        log.info("show all", .{});
        return;
    }

    if (ls_args.isPresent("recursive")) {
        log.info("show recursive", .{});
        return;
    }

    if (ls_args.valueOf("ignore")) |pattern| {
        log.info("ignore pattern = {s}", .{pattern});
        return;
    }

    if (ls_args.isPresent("color")) {
        const when = ls_args.valueOf("color").?;

        log.info("color={s}", .{when});
        return;
    }
}
