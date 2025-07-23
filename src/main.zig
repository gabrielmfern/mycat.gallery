const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.log.warn("Memory leak detected", .{});
        }
    }
    const allocator = gpa.allocator();

    const address = try std.net.Address.resolveIp("127.0.0.1", 3000);

    var server = try address.listen(.{});
    defer server.deinit();
    std.log.info("Server listening on http://localhost:3000", .{});

    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();

        var head_buffer: [1024]u8 = undefined;
        var http_server = std.http.Server.init(connection, &head_buffer);
        var http_request = try http_server.receiveHead();

        if (http_request.head.content_length) |content_length| {
            const reader = try http_request.reader();
            const request_body = try allocator.alloc(u8, content_length);
            defer allocator.free(request_body);
            _ = try reader.readAll(request_body);

            std.debug.print("Received request with body: {s}\n", .{request_body});
        }

        try http_request.respond("This is some text for you to be happy with!", .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/plain" },
            },
        });
    }
}
