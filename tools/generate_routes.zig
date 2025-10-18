const std = @import("std");
const glue = @import("glue");

fn alphabetic_sort(_: void, left: []const u8, right: []const u8) bool {
    return !std.mem.lessThan(u8, left, right);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var imports = std.ArrayList([]const u8).init(allocator);

    const app_directory = try std.fs.cwd().openDir("./src/app", .{ .iterate = true });
    var app_walker = try app_directory.walk(allocator);
    defer app_walker.deinit();
    while (try app_walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, "route.zig")) {
            const import = try std.mem.concat(
                allocator,
                u8,
                &.{ "glue.Route.from(@import(\"./app/", entry.path, "\"), \"/", entry.path, "\")" },
            );
            try imports.append(import);
        }
    }

    std.mem.sort([]const u8, imports.items, void{}, alphabetic_sort);

    const paths = try std.mem.join(allocator, ", ", imports.items);

    const routes_file = try std.mem.concat(
        allocator,
        u8,
        &.{
            "// This file is auto-generated. Do not edit.\n",
            "const glue = @import(\"glue\");\n",
            "pub const routes: []const glue.Route = &.{ ",
            paths,
            " };\n",
        },
    );

    const args = try std.process.argsAlloc(allocator);

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
