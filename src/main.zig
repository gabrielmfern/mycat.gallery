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

    const ReceivedHeadError = std.http.Server.ReceiveHeadError;
    // Catch connection errors early during header parsing
    var http_request = http_server.receiveHead() catch |err| {
        switch (err) {
            ReceivedHeadError.HttpConnectionClosing => {
                std.log.debug("HTTP connection closing during header parsing", .{});
                return;
            },
            else => return err,
        }
    };

    std.log.debug("{s} {s}", .{
        @tagName(http_request.head.method),
        http_request.head.target,
    });

    var handled = false;
    var connection_alive = true;

    inline for (routes) |route| {
        if (route.predicate(&http_request)) {
            route.handler(&http_request) catch |err| {
                // Check if it's a connection-related error
                const WriteError = std.http.Server.Response.WriteError;
                switch (err) {
                    WriteError.ConnectionResetByPeer => {
                        std.log.debug("Connection reset during response: {}", .{err});
                        connection_alive = false;
                    },
                    WriteError.BrokenPipe => {
                        std.log.debug("Broken pipe during response: {}", .{err});
                        connection_alive = false;
                    },
                    else => {
                        try http_request.respond("Internal Server Error", .{
                            .status = .internal_server_error,
                            .extra_headers = &.{
                                .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                            },
                        });
                        return err;
                    },
                }
            };
            handled = true;
            break;
        }
    }

    if (!handled and connection_alive) {
        not_found(&http_request) catch |err| {
            const WriteError = std.http.Server.Response.WriteError;
            switch (err) {
                WriteError.ConnectionResetByPeer, WriteError.BrokenPipe => {
                    std.log.debug("Connection reset during 404 response: {}", .{err});
                },
                else => std.log.err("Error sending 404 response: {}", .{err}),
            }
        };
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

    const address = try std.net.Address.resolveIp("0.0.0.0", 3000);

    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();
    std.log.info("Server listening on http://0.0.0.0:3000", .{});
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
