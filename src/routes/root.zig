const http = @import("std").http;
const helper = @import("../helper.zig");

pub const predicate = helper.Predicate.exact(
    "/",
    http.Method.GET,
);

pub fn handler(request: *http.Server.Request) anyerror!void {
    try request.respond(
        "This is some text for you to be happy with!",
        .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/plain" },
            },
        },
    );
}
