const std = @import("std");
const http = std.http;

pub const Route = struct {
    predicate: fn (request: *const http.Server.Request) bool,
    handler: fn (request: *http.Server.Request) anyerror!void,

    pub fn from(module: anytype) Route {
        return Route{
            .predicate = @field(module, "predicate"),
            .handler = @field(module, "handler"),
        };
    }
};

pub const Predicate = struct {
    pub fn exact(
        comptime expected: []const u8,
        comptime method: http.Method,
    ) (fn (request: *const http.Server.Request) bool) {
        return struct {
            fn predicate(request: *const http.Server.Request) bool {
                return std.mem.eql(u8, request.head.target, expected) and
                    request.head.method == method;
            }
        }.predicate;
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
