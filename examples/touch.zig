const std = @import("std");
const yazap = @import("yazap");

const allocator = std.heap.page_allocator;
const App = yazap.App;
const Arg = yazap.Arg;

pub fn main() anyerror!void {
    var app = App.init(allocator, "mytouch", null);
    defer app.deinit();

    var touch = app.rootCommand();
    touch.setProperty(.help_on_empty_args);

    try touch.addArg(Arg.positionalMultiValues("FILE...", null, null));
    touch.setProperty(.positional_arg_required);

    try touch.addArg(Arg.booleanOption("no-create", 'c', "Do not create any files"));
    try touch.addArg(Arg.booleanOption("version", 'v', "Display app version"));

    const matches = try app.parseProcess();

    if (matches.containsArg("version")) {
        std.debug.print("v0.1.0\n", .{});
        return;
    }

    if (matches.getMultiValues("FILE...")) |file_names| {
        for (file_names) |file_name| {
            if (matches.containsArg("no-create")) {
                std.debug.print("File {s} does not exist and it will not be created\n", .{file_name});
            } else {
                var file = try std.fs.cwd().createFile(file_name, .{});
                defer file.close();
            }
        }
    }
}
