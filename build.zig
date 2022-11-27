const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const regex_pkg = std.build.Pkg{ .name = "zig-regex", .source = .{ .path = "libs/zig-regex/src/regex.zig" } };

    const lib = b.addStaticLibrary("jsonschema", "src/jsonschema.zig");
    lib.setBuildMode(mode);
    lib.install();

    const c_lib = b.addStaticLibrary("c_jsonschema", "src/c_jsonschema.zig");
    c_lib.setBuildMode(mode);
    c_lib.addPackage(regex_pkg);
    c_lib.linkLibC();
    c_lib.step.dependOn(&lib.step);
    c_lib.install();

    const jsonschema_tests = b.addTest("src/tests.zig");
    jsonschema_tests.setBuildMode(mode);
    jsonschema_tests.addPackage(regex_pkg);
    jsonschema_tests.linkLibrary(c_lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&jsonschema_tests.step);
}
