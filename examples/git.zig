const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const App = yazap.App;
const Arg = yazap.Arg;

// git init
// git commit -m "message"
// git pull <remote>
// git push <remote> <branch_name>

pub fn main() anyerror!void {
    var app = App.init(allocator, "mygit", null);
    defer app.deinit();

    var git = app.rootCommand();

    var cmd_commit = app.createCommand("commit", "Record changes to the repository");
    try cmd_commit.addArg(Arg.singleArgumentOption("message", 'm', "commit message"));

    var cmd_pull = app.createCommand("pull", "Fetch from remote branch and merge it to local");
    try cmd_pull.addArg(Arg.positional("REMOTE", null, null));

    var cmd_push = app.createCommand("push", "Update the remote branch");
    try cmd_pull.addArg(Arg.positional("REMOTE", null, null));
    try cmd_pull.addArg(Arg.positional("BRANCH_NAME", null, null));

    try git.addSubcommand(app.createCommand("init", "Create an empty Git repository or reinitialize an existing one"));
    try git.addSubcommand(cmd_commit);
    try git.addSubcommand(cmd_pull);
    try git.addSubcommand(cmd_push);

    const matches = try app.parseProcess();

    if (matches.isArgumentPresent("init")) {
        std.debug.print("Initilize empty repo", .{});
        return;
    }

    if (matches.subcommandMatches("commit")) |commit_matches| {
        if (commit_matches.valueOf("message")) |message| {
            std.log.info("Commit message {s}", .{message});
            return;
        }
    }

    if (matches.subcommandMatches("push")) |push_matches| {
        if (push_matches.isArgumentPresent("REMOTE") and push_matches.isArgumentPresent("BRANCH_NAME")) {
            const remote = push_matches.valueOf("REMOTE").?;
            const branch_name = push_matches.valueOf("BRANCH_NAME").?;

            std.log.info("REMOTE={s}, BRANCH_NAME={s}", .{ remote, branch_name });
            return;
        }
    }
}
