const std = @import("std");
const http = std.http;

pub const Route = struct {
    method: http.Method,
    /// Should be everything that comes after the domain name in
    /// the URL. Including the leading slash.
    pathname: []const u8,
    handler: *const fn (
        request: *http.Server.Request,
    ) anyerror!void,

    pub fn from(module: anytype) Route {
        return Route{
            .method = @field(module, "method"),
            .pathname = @field(module, "pathname"),
            .handler = @field(module, "handler"),
        };
    }
};

pub fn readBody(
    request: http.Server.Request,
    allocator: std.mem.Allocator,
) !?[]const u8 {
    if (request.head.content_length) |content_length| {
        const reader = try request.reader();
        const body = try allocator.alloc(
            u8,
            content_length,
        );
        _ = try reader.readAll(body);

        return body;
    } else {
        return null;
    }
}
