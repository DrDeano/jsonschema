const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("jsonschema", "src/jsonschema.zig");
    lib.setBuildMode(mode);
    lib.install();

    const jsonschema_tests = b.addTest("src/jsonschema.zig");
    jsonschema_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&jsonschema_tests.step);
}
