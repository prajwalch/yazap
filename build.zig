const std = @import("std");

pub fn build(b: *std.Build) void {
    const yazap = b.addModule("yazap", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = b.graph.host,
    });

    testStep(b);
    examplesStep(b, yazap);
    docsStep(b, yazap);
}

fn testStep(b: *std.Build) void {
    // Test file information.
    const test_module = b.addModule("test", .{
        .root_source_file = b.path("src/test.zig"),
        .target = b.graph.host,
    });
    const tests = b.addTest(.{ .root_module = test_module });
    // This runs the unit tests.
    const runner = b.addRunArtifact(tests);

    const step = b.step("test", "Run unit tests");
    step.dependOn(&runner.step);
}

fn examplesStep(b: *std.Build, yazap: *std.Build.Module) void {
    var threaded_io: std.Io.Threaded = .init_single_threaded;
    defer threaded_io.deinit();
    const io = threaded_io.io();
    var dir = std.Io.Dir.cwd().openDir(io, "./examples/", .{ .iterate = true }) catch return;
    defer dir.close(io);

    const step = b.step("examples", "Build all the examples");
    var examples = dir.iterate();

    while (examples.next(io) catch @panic("failed to get example file")) |example_file| {
        std.debug.assert(example_file.kind == .file);
        // If not a .zig file, skip it
        if (!std.mem.endsWith(u8, example_file.name, ".zig")) continue;

        // Example file path.
        const example_file_path = b.path(b.fmt("examples/{s}", .{example_file.name}));
        // Example file name without extension.
        const example_name = std.fs.path.stem(example_file_path.getDisplayName());

        // Binary information of an example.
        const example_exe_module = b.addModule(example_name, .{
            .root_source_file = example_file_path,
            .target = b.graph.host,
        });
        const executable = b.addExecutable(.{
            .name = example_name,
            .root_module = example_exe_module,
        });
        // Add yazap as a dependency.
        executable.root_module.addImport("yazap", yazap);

        // This copies the compiled binary to the `.zig-out/bin`.
        const installer = b.addInstallArtifact(executable, .{});
        step.dependOn(&installer.step);
    }
}

fn docsStep(b: *std.Build, yazap: *std.Build.Module) void {
    const lib = b.addLibrary(.{
        .name = "yazap",
        .root_module = yazap,
    });
    const docs_step = b.step("doc", "Emit documentation");

    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });

    docs_step.dependOn(&docs_install.step);
    b.getInstallStep().dependOn(docs_step);
}
