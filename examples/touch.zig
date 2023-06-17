const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const App = yazap.App;
const Arg = yazap.Arg;

pub fn main() anyerror!void {
    var app = App.init(allocator, "mytouch", null);
    defer app.deinit();

    var touch = app.rootCommand();

    try touch.addArg(Arg.positional("FILE_NAME", null, null));
    touch.setProperty(.positional_arg_required);

    try touch.addArg(Arg.booleanOption("no-create", 'c', "Do not create any files"));
    try touch.addArg(Arg.booleanOption("version", 'v', "Display app version"));

    const matches = try app.parseProcess();

    if (matches.isArgumentPresent("version")) {
        std.debug.print("v0.1.0", .{});
        return;
    }

    if (matches.valueOf("FILE_NAME")) |file_name| {
        if (matches.isArgumentPresent("no-create")) {
            std.debug.print("I'am not creating it", .{});
        } else {
            var file = try std.fs.cwd().createFile(file_name, .{});
            defer file.close();
        }
    }
}
