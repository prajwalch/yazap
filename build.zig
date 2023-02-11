const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "yazap",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
        .version = std.builtin.Version{ .major = 0, .minor = 4 },
    });
    lib.install();

    const main_tests = b.addTest(.{ .root_source_file = .{ .path = "src/test.zig" } });
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const docs = b.addTest(.{ .root_source_file = .{ .path = "src/lib.zig" } });
    docs.emit_docs = .emit;

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);

    const examples_step = b.step("examples", "Build all the example");

    inline for (.{ "git", "touch", "ls" }) |example_name| {
        const example_exe = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = "examples/" ++ example_name ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example_exe.addAnonymousModule("yazap", .{
            .source_file = .{ .path = "src/lib.zig" },
        });
        example_exe.install();

        examples_step.dependOn(b.getInstallStep());
    }
}
