const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const generate_routes = b.addExecutable(.{
        .name = "generate_routes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_routes.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const generate_routes_step = b.addRunArtifact(generate_routes);
    var wf = b.addUpdateSourceFiles();
    wf.addCopyFileToSource(
        generate_routes_step.addOutputFileArg("routes.zig"),
        "./src/routes.zig",
    );

    const glue = b.createModule(.{
        .root_source_file = b.path("glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport(
        "glue",
        glue,
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
    run_cmd.step.dependOn(&wf.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&wf.step);
    run_step.dependOn(&run_cmd.step);

    const webserver_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    webserver_tests.step.dependOn(&wf.step);
    const run_webserver_tests = b.addRunArtifact(webserver_tests);

    const glue_tests = b.addTest(.{
        .root_module = glue,
    });
    const run_glue_tests = b.addRunArtifact(glue_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&wf.step);
    test_step.dependOn(&run_glue_tests.step);
    test_step.dependOn(&run_webserver_tests.step);
}
