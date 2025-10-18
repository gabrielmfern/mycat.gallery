const http = @import("std").http;

pub fn handler(request: *http.Server.Request) anyerror!void {
    try request.respond(@embedFile("./favicon.ico"), .{
        .status = .ok,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "image/x-icon" },
        },
    });
}
