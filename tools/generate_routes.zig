const std = @import("std");
const glue = @import("glue");

fn read_paths_from(
    directory_path: []const u8,
    imports: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !void {
    const directory = try std.fs.cwd().openDir(
        directory_path,
        .{ .iterate = true },
    );
    var iterator = directory.iterate();
    while (try iterator.next()) |entry| {
        const path = try std.fs.path.join(
            allocator,
            &.{ directory_path, entry.name },
        );
        defer allocator.free(path);
        if (entry.kind == .directory) {
            try read_paths_from(path, imports, allocator);
        } else if (entry.kind == .file and std.mem.endsWith(
            u8,
            entry.name,
            "route.zig",
        )) {
            const import = try std.mem.concat(
                allocator,
                u8,
                &.{ "@import(\"", path, "\")" },
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
    try read_paths_from("./src/app", &imports, allocator);

    const paths = try std.mem.join(allocator, ",", imports.items);
    defer allocator.free(paths);

    const routes_file = try std.mem.concat(
        allocator,
        u8,
        &.{ "pub const routes = &.{", paths, "};" },
    );
    defer allocator.free(routes_file);
    const stdout = std.io.getStdOut();
    _ = try stdout.write(routes_file);
}
