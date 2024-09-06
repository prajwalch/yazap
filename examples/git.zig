const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const App = yazap.App;
const Arg = yazap.Arg;

pub fn main() anyerror!void {
    var app = App.init(allocator, "mygit", null);
    defer app.deinit();

    var git = app.rootCommand();
    git.setProperty(.help_on_empty_args);

    // git init
    try git.addSubcommand(app.createCommand(
        "init",
        "Create an empty Git repository or reinitialize an existing one",
    ));

    // git commit -m "message"
    var cmd_commit = app.createCommand("commit", "Record changes to the repository");
    try cmd_commit.addArg(Arg.singleValueOption("message", 'm', "commit message"));

    // git push <remote> <branch_name>
    var cmd_push = app.createCommand("push", "Update the remote branch");
    try cmd_push.addArg(Arg.positional("REMOTE", null, null));
    try cmd_push.addArg(Arg.positional("BRANCH_NAME", null, null));

    // git pull <remote>
    var cmd_pull = app.createCommand("pull", "Fetch from remote branch and merge it to local");
    try cmd_pull.addArg(Arg.positional("REMOTE", null, null));

    try git.addSubcommand(cmd_commit);
    try git.addSubcommand(cmd_push);
    try git.addSubcommand(cmd_pull);

    const matches = try app.parseProcess();

    if (matches.containsArg("init")) {
        std.debug.print("Initilize empty repo", .{});
        return;
    }

    if (matches.subcommandMatches("commit")) |commit_matches| {
        if (commit_matches.getSingleValue("message")) |message| {
            std.log.info("Commit message {s}", .{message});
            return;
        }
    }

    if (matches.subcommandMatches("push")) |push_matches| {
        if (push_matches.containsArg("REMOTE") and push_matches.containsArg("BRANCH_NAME")) {
            const remote = push_matches.getSingleValue("REMOTE").?;
            const branch_name = push_matches.getSingleValue("BRANCH_NAME").?;

            std.log.info("REMOTE={s}, BRANCH_NAME={s}", .{ remote, branch_name });
            return;
        }
    }
}
