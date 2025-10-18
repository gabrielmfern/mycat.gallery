const std = @import("std");
const http = std.http;
const glue = @import("glue");
const Database = @import("database.zig");

const routes = @import("routes.zig").routes;

threadlocal var thread_allocator: std.mem.Allocator = undefined;
threadlocal var thread_database: Database = undefined;

pub fn use_allocator() std.mem.Allocator {
    return thread_allocator;
}

pub fn use_database() *Database {
    return &thread_database;
}

fn handle_connection(connection: std.net.Server.Connection) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    thread_allocator = arena.allocator();
    defer arena.deinit();

    thread_database = try Database.init(thread_allocator);
    defer thread_database.deinit();
    std.log.debug("Connection to database established", .{});

    defer connection.stream.close();
    var head_buffer: [1024]u8 = undefined;
    var http_server = std.http.Server.init(connection, &head_buffer);

    var http_request = try http_server.receiveHead();
    std.log.debug("{s} {s}", .{ @tagName(http_request.head.method), http_request.head.target });

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
            std.log.warn("Memory leak in main thread detected", .{});
        }
    }
    const allocator = gpa.allocator();

    const address = try std.net.Address.resolveIp("127.0.0.1", 3000);

    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();
    std.log.info("Server listening on http://localhost:3000", .{});
    std.log.debug("Registered {d} routes", .{routes.len});

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
