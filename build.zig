const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const compile_swift = b.addSystemCommand(&[_][]const u8{
        "swiftc",
        "-working-directory",
        b.cache_root,
        "-emit-library",
        "-o",
        "libclip.a",
        b.pathFromRoot("src/libclip.swift"),
    });
    const compile_swift_needed = buildNeeded("src/libclip.swift", b.pathJoin(&.{ b.cache_root, "libclip.a" }));

    const exe = b.addExecutable("clip", "src/main.zig");
    if (compile_swift_needed) exe.step.dependOn(&compile_swift.step);
    exe.addLibraryPath(b.cache_root);
    exe.linkSystemLibrary("clip");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    // zig build run
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // zig build test
    const exe_tests = b.addTest("src/main.zig");
    if (compile_swift_needed) exe_tests.step.dependOn(&compile_swift.step);
    exe_tests.addLibraryPath(b.cache_root);
    exe_tests.linkSystemLibrary("clip");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

fn buildNeeded(source: []const u8, built: []const u8) bool {
    const sourceFile = std.fs.cwd().openFile(source, .{}) catch unreachable;
    defer sourceFile.close();
    const builtFile = std.fs.cwd().openFile(built, .{}) catch return true;
    defer builtFile.close();

    const sourceFileModified = (sourceFile.metadata() catch return true).modified();
    const builtFileCreated = (builtFile.metadata() catch return true).created().?;
    return sourceFileModified > builtFileCreated;
}
