const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../../main.zig").use_allocator;
const not_found = @import("../../../main.zig").not_found;

fn getMimeType(filename: []const u8) []const u8 {
    if (std.mem.endsWith(u8, filename, ".png")) {
        return "image/png";
    } else if (std.mem.endsWith(u8, filename, ".jpg") or std.mem.endsWith(u8, filename, ".jpeg")) {
        return "image/jpeg";
    } else if (std.mem.endsWith(u8, filename, ".gif")) {
        return "image/gif";
    } else if (std.mem.endsWith(u8, filename, ".webp")) {
        return "image/webp";
    } else if (std.mem.endsWith(u8, filename, ".heic") or std.mem.endsWith(u8, filename, ".heif")) {
        return "image/heic";
    } else if (std.mem.endsWith(u8, filename, ".avif")) {
        return "image/avif";
    } else if (std.mem.endsWith(u8, filename, ".bmp")) {
        return "image/bmp";
    } else if (std.mem.endsWith(u8, filename, ".svg")) {
        return "image/svg+xml";
    } else {
        return "application/octet-stream";
    }
}

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
    defer picture.close();

    const metadata = try picture.metadata();
    var reader = picture.reader();

    // Detect MIME type from file extension
    const content_type = getMimeType(filename.?);

    // Use streaming response with content-length
    var send_buffer: [8192]u8 = undefined;
    var response = request.respondStreaming(.{
        .send_buffer = &send_buffer,
        .content_length = metadata.size(),
        .respond_options = .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = content_type },
            },
        },
    });

    // Stream the file in chunks (64KB for better performance)
    var buffer: [65536]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(buffer[0..]);
        if (bytes_read == 0) break;

        try response.writeAll(buffer[0..bytes_read]);
    }

    try response.end();
}
