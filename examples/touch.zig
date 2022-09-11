const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const flag = yazap.flag;
const Command = yazap.Command;
const Yazap = yazap.Yazap;

pub fn main() anyerror!void {
    var app = Yazap.init(allocator, "mytouch");
    defer app.deinit();

    var touch = app.rootCommand();

    try touch.takesSingleValue("FILE_NAME");
    touch.argRequired(true);

    try touch.addArg(flag.boolean("no-create", 'c'));
    try touch.addArg(flag.boolean("version", 'v'));
    try touch.addArg(flag.boolean("help", 'h'));

    var args = try app.parseProcess();

    if (args.isPresent("help")) {
        std.debug.print("Show help", .{});
        return;
    }

    if (args.isPresent("version")) {
        std.debug.print("v0.1.0", .{});
        return;
    }

    if (args.valueOf("FILE_NAME")) |file_name| {
        if (args.isPresent("no-create")) {
            std.debug.print("I'am not creating it", .{});
        } else {
            var file = try std.fs.cwd().createFile(file_name);
            defer file.close();
        }
    }
}
