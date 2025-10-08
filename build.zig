const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport(
        "glue",
        b.createModule(.{
            .root_source_file = b.path("glue.zig"),
            .target = target,
            .optimize = optimize,
        }),
    );
    exe_mod.addImport(
        "sqlite",
        b.dependency("sqlite", .{}).module("sqlite"),
    );
    exe_mod.addImport(
        "uuid",
        b.dependency("uuid", .{}).module("uuid"),
    );

    const exe = b.addExecutable(.{
        .name = "mypet_gallery",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
