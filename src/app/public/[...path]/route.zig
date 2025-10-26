const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../../main.zig").use_allocator;
const not_found = @import("../../../main.zig").not_found;

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();

    const path = try std.mem.concat(
        allocator,
        u8,
        &.{
            ".",
            request.head.target,
        },
    );
    var iterator = std.mem.splitScalar(u8, path, '/');
    while (iterator.next()) |segment| {
        if (std.mem.containsAtLeast(u8, segment, 1, "..")) {
            std.log.warn("Directory traversal attempt blocked: {s}", .{path});
            try request.respond(
                "Access denied",
                .{
                    .status = .forbidden,
                    .extra_headers = &.{
                        .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                    },
                },
            );
            return;
        }
    }
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try not_found(request);
        return;
    };
    defer file.close();

    const extension = std.fs.path.extension(path);

    const content_type = content_type: {
        if (std.mem.eql(u8, extension, ".css")) break :content_type "text/css; charset=UTF-8";
        if (std.mem.eql(u8, extension, ".js")) break :content_type "application/javascript; charset=UTF-8";
        if (std.mem.eql(u8, extension, ".svg")) break :content_type "image/svg+xml; charset=UTF-8";
        if (std.mem.eql(u8, extension, ".png")) break :content_type "image/png";
        if (std.mem.eql(u8, extension, ".jpg")) break :content_type "image/jpeg";
        if (std.mem.eql(u8, extension, ".jpeg")) break :content_type "image/jpeg";
        if (std.mem.eql(u8, extension, ".gif")) break :content_type "image/gif";
        std.log.warn("Unknown file extension: {s}", .{extension});
        break :content_type "text/plain; charset=UTF-8";
    };

    const metadata = try file.metadata();
    var reader = file.reader();
    const contents = try reader.readAllAlloc(
        allocator,
        @intCast(metadata.size()),
    );
    try request.respond(
        contents,
        .{
            .status = .ok,
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = content_type,
                },
            },
        },
    );
}
