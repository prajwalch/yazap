const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const yazap_mod = b.addModule("yazap", .{ .source_file = .{ .path = "src/lib.zig" } });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_tests = b.addTest(.{ .root_source_file = .{ .path = "src/test.zig" } });
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const docs = b.addTest(.{ .root_source_file = .{ .path = "src/lib.zig" } });
    docs.emit_docs = .emit;

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);

    const examples_step = b.step("examples", "Build all the example");

    inline for (.{ "git", "touch", "ls" }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example);

        example.addModule("yazap", yazap_mod);
        example.addAnonymousModule("yazap", .{
            .source_file = .{ .path = "src/lib.zig" },
        });
        examples_step.dependOn(&install_example.step);
    }
}
