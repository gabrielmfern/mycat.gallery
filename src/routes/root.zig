const std = @import("std");
const http = std.http;
const glue = @import("../glue.zig");
const layout = @import("../components/layout.zig").layout;

const use_allocator = @import("../main.zig").use_allocator;

pub const predicate = glue.Predicates.exact(
    "/",
    http.Method.GET,
);

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();
    const html = try glue.html(.{
        layout("mypet", .{
            "<h1>Welcome to Zig HTTP Server</h1>",
            "<p>This is a simple HTTP server written in Zig.</p>",
            "<p>Feel free to explore the code and modify it as you wish!</p>",
            "<p>Current elapsed time: ",
            std.time.timestamp(),
            "</p>",
        }),
    }, allocator);
    defer allocator.free(html);
    try request.respond(
        html,
        .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html; charset=UTF-8" },
            },
        },
    );
}
