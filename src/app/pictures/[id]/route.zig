const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../../main.zig").use_allocator;

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();

    const path = request.head.target;
    const picture = std.fs.cwd().openFile(
        std.mem.trim(u8, path, "/"),
        .{},
    ) catch {
        try request.respond(
            "Not Found",
            .{
                .status = .not_found,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                },
            },
        );
        return;
    };
    const metadata = try picture.metadata();
    var reader = picture.reader();
    const contents = try reader.readAllAlloc(allocator, @intCast(metadata.size()));
    defer allocator.free(contents);
    try request.respond(
        contents,
        .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "image/png" },
            },
        },
    );
}
