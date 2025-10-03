const std = @import("std");
const http = std.http;
const glue = @import("glue");
const Database = @import("database.zig");

const routes = &[_]glue.Route{
    glue.Route.from(@import("routes/root.zig")),
    glue.Route.from(@import("routes/assets.zig")),
    glue.Route.from(@import("routes/pictures.zig")),
    glue.Route.from(@import("routes/upload.zig")),
};

var allocator: std.mem.Allocator = undefined;
var database: Database = undefined;

pub fn use_allocator() std.mem.Allocator {
    return allocator;
}

pub fn use_database() *Database {
    return &database;
}

fn handle_connection(connection: std.net.Server.Connection) anyerror!void {
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

    database = try Database.init(allocator);
    defer database.deinit();
    std.log.debug("Connection to database established", .{});

    while (true) {
        const connection = try server.accept();
        const thread = try std.Thread.spawn(.{
            .allocator = allocator,
        }, handle_connection, .{connection});
        thread.detach();
    }
}
test {
    std.testing.refAllDecls(@import("glue"));
}
