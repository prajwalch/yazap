const std = @import("std");

pub fn build(b: *std.Build) void {
    const yazap_mod = b.addModule("yazap", .{ .root_source_file = b.path("src/lib.zig") });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);

    const docs_test = b.addTest(.{ .root_source_file = b.path("src/lib.zig") });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_test.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&install_docs.step);

    const examples_step = b.step("examples", "Build all the example");

    inline for (.{ "git", "touch", "ls" }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{example_name})),
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example, .{});
        example.root_module.addImport("yazap", yazap_mod);
        examples_step.dependOn(&example.step);
        examples_step.dependOn(&install_example.step);
    }
}
