const std = @import("std");

fn import_routes_into(
    b: *std.Build,
    module: *std.Build.Module,
    root_path: []const u8,
) void {
    const app_directory = try std.fs.cwd().openDir("./src/app", .{
        .iterate = true,
    });
    var route_files_iterator = app_directory.iterate();

    while (try route_files_iterator.next()) |entry| {
        if (entry.kind == .directory) {
            import_routes_into(
                b,
                module,
                b.pathJoin(&.{ root_path, entry.name }),
            );
        }
        if (entry.kind == .file) {
            if (std.mem.endsWith(u8, entry.name, "route.zig")) {
                module.addImport(entry.name, b.createModule(.{
                    .root_source_file = b.pathJoin(&.{
                        root_path,
                        entry.name,
                    }),
                    .target = target,
                    .optimize = optimize,
                }));
            }
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const Route = struct {
        module: ?*b.Module,
        path: []const u8,
    };

    const routes_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    import_routes_into(b, routes_module, "./src/app");

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
