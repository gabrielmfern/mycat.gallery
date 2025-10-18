const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../../main.zig").use_allocator;
const not_found = @import("../../../main.zig").not_found;

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();

    var segments_iterator = std.mem.splitBackwardsSequence(
        u8,
        request.head.target,
        "/",
    );
    const filename = segments_iterator.next();
    if (filename == null) {
        try request.respond(
            "An unexpected error happened",
            .{
                .status = .internal_server_error,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                },
            },
        );
        return;
    }

    const path = try std.mem.concat(allocator, u8, &.{ "./pictures/", filename.? });

    const picture = std.fs.cwd().openFile(
        path,
        .{},
    ) catch {
        try not_found(request);
        return;
    };
    const metadata = try picture.metadata();
    var reader = picture.reader();
    const contents = try reader.readAllAlloc(
        allocator,
        @intCast(metadata.size()),
    );

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
