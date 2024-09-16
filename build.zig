const std = @import("std");

pub fn build(b: *std.Build) void {
    const yazap = b.addModule("yazap", .{ .root_source_file = b.path("src/lib.zig") });

    testStep(b);
    examplesStep(b, yazap);
}

fn testStep(b: *std.Build) void {
    // Test file information.
    const tests = b.addTest(.{ .root_source_file = b.path("src/test.zig") });
    // This runs the unit tests.
    const runner = b.addRunArtifact(tests);

    const step = b.step("test", "Run unit tests");
    step.dependOn(&runner.step);
}

fn examplesStep(b: *std.Build, yazap: *std.Build.Module) void {
    var dir = std.fs.cwd().openDir("./examples/", .{ .iterate = true }) catch return;
    defer dir.close();

    const step = b.step("examples", "Build all the examples");
    var examples = dir.iterate();

    while (examples.next() catch @panic("failed to get example file")) |example_file| {
        std.debug.assert(example_file.kind == .file);

        // Example file path.
        const example_file_path = b.path(b.fmt("examples/{s}", .{example_file.name}));
        // Example file name without extension.
        const example_name = std.fs.path.stem(example_file_path.getDisplayName());

        // Binary information of an example.
        const executable = b.addExecutable(.{
            .name = example_name,
            .root_source_file = example_file_path,
            .target = b.graph.host,
        });
        // Add yazap as a dependency.
        executable.root_module.addImport("yazap", yazap);

        // This copies the compiled binary to the `.zig-out/bin`.
        const installer = b.addInstallArtifact(executable, .{});
        step.dependOn(&installer.step);
    }
}
