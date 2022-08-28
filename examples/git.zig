const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const flag = yazap.flag;
const Command = yazap.Command;
const Arg = yazap.Arg;

// git init
// git commit -m "message"
// git pull <remote>
// git push <remote> <branch_name>

pub fn main() anyerror!void {
    var git = Command.new(allocator, "mygit");
    defer git.deinit();

    var cmd_commit = Command.new(allocator, "commit");
    try cmd_commit.addArg(flag.argOne("message", 'm'));

    var cmd_pull = Command.new(allocator, "pull");
    try cmd_pull.takesSingleValue("REMOTE");
    cmd_pull.argRequired(true);

    var cmd_push = Command.new(allocator, "push");
    try cmd_push.takesSingleValue("REMOTE");
    try cmd_push.takesSingleValue("BRANCH_NAME");
    try cmd_push.argRequired(true);

    try git.addSubcommand(Command.new(allocator, "init"));
    try git.addSubcommand(cmd_commit);
    try git.addSubcommand(cmd_pull);
    try git.addSubcommand(cmd_push);

    var args = try git.parseProcess();
    defer args.deinit();

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
