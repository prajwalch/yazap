const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("yazap", "src/lib.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/test.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const docs = b.addTest("src/lib.zig");
    docs.emit_docs = .emit;

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);

    const examples_step = b.step("examples", "Build all the example");

    inline for (.{ "git", "touch", "ls" }) |example_name| {
        const example_exe = b.addExecutable(example_name, "examples/" ++ example_name ++ ".zig");
        example_exe.setTarget(target);
        example_exe.setBuildMode(mode);
        example_exe.addPackagePath("yazap", "src/lib.zig");
        example_exe.install();

        examples_step.dependOn(b.getInstallStep());
    }
}
