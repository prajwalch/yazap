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

    const args = try app.parseProcess();

    if (args.isPresent("init")) {
        std.debug.print("Initilize empty repo", .{});
        return;
    }

    if (args.subcommandContext("commit")) |commit_args| {
        if (commit_args.valueOf("message")) |message| {
            std.log.info("Commit message {s}", .{message});
            return;
        }
    }

    if (args.subcommandContext("push")) |push_args| {
        if (push_args.isPresent("REMOTE") and push_args.isPresent("BRANCH_NAME")) {
            const remote = push_args.valueOf("REMOTE").?;
            const branch_name = push_args.valueOf("BRANCH_NAME").?;

            std.log.info("REMOTE={s}, BRANCH_NAME={s}", .{ remote, branch_name });
            return;
        }
    }
}
