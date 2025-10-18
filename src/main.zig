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

pub fn use_database() !Database {
    thread_database = try Database.init(use_allocator());
    std.log.debug("Connection to database established", .{});
    return thread_database;
}

pub fn not_found(request: *http.Server.Request) !void {
    try request.respond(
        "Not Found",
        .{
            .status = .not_found,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
            },
        },
    );
}

fn handle_connection(connection: std.net.Server.Connection) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    thread_allocator = arena.allocator();
    defer arena.deinit();

    defer connection.stream.close();
    var head_buffer: [1024]u8 = undefined;
    var http_server = std.http.Server.init(connection, &head_buffer);

    var http_request = try http_server.receiveHead();
    std.log.debug("{s} {s}", .{ @tagName(http_request.head.method), http_request.head.target });

    var handled = false;
    inline for (routes) |route| {
        if (route.predicate(&http_request)) {
            try route.handler(&http_request);
            handled = true;
            break;
        }
    }
    if (!handled) {
        try not_found(&http_request);
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
