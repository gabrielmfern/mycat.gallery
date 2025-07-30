const std = @import("std");
const http = std.http;
const glue = @import("glue");

const routes = &[_]glue.Route{
    glue.Route.from(@import("routes/root.zig")),
};

var allocator: std.mem.Allocator = undefined;

pub fn use_allocator() std.mem.Allocator {
    return allocator;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.log.warn("Memory leak detected", .{});
        }
    }
    allocator = gpa.allocator();

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
        std.log.debug("{s} {s}", .{
            @tagName(http_request.head.method),
            http_request.head.target,
        });

        inline for (routes) |route| {
            if (route.predicate(&http_request)) {
                try route.handler(&http_request);
                break;
            }
        }
    }
}

test {
    std.testing.refAllDecls(@import("glue"));
}
