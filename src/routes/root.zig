const http = @import("std").http;
const glue = @import("../glue.zig");

pub const predicate = glue.Predicates.exact(
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
