const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../../main.zig").use_allocator;
const not_found = @import("../../../main.zig").not_found;

const globals_css = @embedFile("./globals.css");
const logo = @embedFile("./logo.svg");

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
        try not_found(request);
    }
}
