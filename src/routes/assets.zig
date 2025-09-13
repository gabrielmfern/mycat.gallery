const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../main.zig").use_allocator;

const globals_css = @embedFile("./assets/globals.css");
const logo = @embedFile("./assets/logo.svg");

pub const predicate = glue.Predicates.starts_with(
    "/assets",
    http.Method.GET,
);

pub fn handler(request: *http.Server.Request) anyerror!void {
    if (std.mem.eql(u8, request.head.target, "/assets/globals.css")) {
        try request.respond(
            globals_css,
            .{
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/css; charset=UTF-8" },
                },
            },
        );
    } else if (std.mem.eql(u8, request.head.target, "/assets/logo.svg")) {
        try request.respond(
            logo,
            .{
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "image/svg+xml; charset=UTF-8" },
                },
            },
        );
    } else {
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
}
