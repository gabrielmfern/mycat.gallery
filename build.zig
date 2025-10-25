const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var wf = b.addUpdateSourceFiles();

    {
        // File-routing strategy
        const generate_routes = b.addExecutable(.{
            .name = "generate_routes",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/generate_routes.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const generate_routes_step = b.addRunArtifact(generate_routes);
        generate_routes_step.has_side_effects = true;
        wf.addCopyFileToSource(
            generate_routes_step.addOutputFileArg("routes.zig"),
            "./src/routes.zig",
        );
    }

    {
        // tailwindcss styles generation
        const tailwindcss_command = b.addSystemCommand(&.{
            "npx",
            "tailwindcss",
            "-i",
            "src/index.css",
            "-o",
        });
        tailwindcss_command.has_side_effects = true;
        wf.addCopyFileToSource(
            tailwindcss_command.addOutputFileArg("generated.css"),
            "./public/generated.css",
        );
    }

    const glue = b.createModule(.{
        .root_source_file = b.path("glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const webserver = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    webserver.addImport(
        "glue",
        glue,
    );
    webserver.addImport(
        "sqlite",
        b.dependency("sqlite", .{}).module("sqlite"),
    );
    webserver.addImport(
        "uuid",
        b.dependency("uuid", .{}).module("uuid"),
    );

    {
        // zig build run
        const webserver_exe = b.addExecutable(.{
            .name = "mypet_gallery",
            .root_module = webserver,
        });
        b.installArtifact(webserver_exe);

        const run_webserver = b.addRunArtifact(webserver_exe);
        run_webserver.step.dependOn(&wf.step);
        run_webserver.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_webserver.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&wf.step);
        run_step.dependOn(&run_webserver.step);
    }

    {
        // zig build test
        const webserver_tests = b.addTest(.{
            .root_module = webserver,
            .test_runner = .{
                .path = b.path("test_runner.zig"),
                .mode = .simple,
            },
        });
        webserver_tests.step.dependOn(&wf.step);
        const run_webserver_tests = b.addRunArtifact(webserver_tests);

        const glue_tests = b.addTest(.{
            .root_module = glue,
            .test_runner = .{
                .path = b.path("test_runner.zig"),
                .mode = .simple,
            },
        });
        const run_glue_tests = b.addRunArtifact(glue_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&wf.step);
        test_step.dependOn(&run_glue_tests.step);
        test_step.dependOn(&run_webserver_tests.step);
    }
}
