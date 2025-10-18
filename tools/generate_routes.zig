const std = @import("std");
const glue = @import("glue");

fn read_paths_from(
    directory: std.fs.Dir,
    base_path: []const u8,
    imports: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !void {
    var iterator = directory.iterate();
    while (try iterator.next()) |entry| {
        const path = try std.fs.path.join(
            allocator,
            &.{ base_path, entry.name },
        );

        defer allocator.free(path);
        if (entry.kind == .directory) {
            try read_paths_from(
                try directory.openDir(entry.name, .{ .iterate = true }),
                path,
                imports,
                allocator,
            );
        } else if (entry.kind == .file and std.mem.endsWith(u8, entry.name, "route.zig")) {
            const import = try std.mem.concat(
                allocator,
                u8,
                &.{ "   glue.Route.from(@import(\"", path, "\"), \"", path, "\")" },
            );
            try imports.append(import);
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.log.warn("Leaked memory", .{});
        }
    }
    const allocator = gpa.allocator();

    var imports = std.ArrayList([]const u8).init(allocator);
    defer imports.deinit();
    defer {
        for (imports.items) |path| {
            allocator.free(path);
        }
    }
    try read_paths_from(
        try std.fs.cwd().openDir("./src/app", .{ .iterate = true }),
        "./app",
        &imports,
        allocator,
    );

    const paths = try std.mem.join(allocator, ",\n", imports.items);
    defer allocator.free(paths);

    const routes_file = try std.mem.concat(
        allocator,
        u8,
        &.{ "const glue = @import(\"glue\");\npub const routes = &.{\n", paths, "\n};" },
    );
    defer allocator.free(routes_file);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("wrong number of arguments", .{});
        return std.process.exit(1);
    }

    const output_file_path = args[1];

    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        std.log.err("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
        return std.process.exit(1);
    };
    defer output_file.close();

    try output_file.writeAll(routes_file);
    return std.process.cleanExit();
}
