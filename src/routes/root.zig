const std = @import("std");
const http = std.http;
const glue = @import("glue");
const layout = @import("../components/layout.zig").layout;

const use_allocator = @import("../main.zig").use_allocator;
const use_database = @import("../main.zig").use_database;

pub const predicate = glue.Predicates.exact(
    "/",
    http.Method.GET,
);

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();
    const database = use_database();
    const page = try database.get_page(1);
    std.log.debug(
        "Loaded page {d} with {d} pictures",
        .{ page.page, page.pictures.len },
    );

    const html = try glue.html(.{
        layout("mypet", .{
            "<form id=\"submitPictureForm\" class=\"ml-auto\" method=\"POST\" enctype=\"multipart/form-data\">",
            "   <input",
            "       name=\"picture\"",
            "       type=\"file\"",
            "       accept=\"image/*\"",
            "       capture=\"environment\"",
            "       onchange=\"fetch('/upload', { method: 'post', body: new FormData(submitPictureForm) })\"",
            "   />",
            "</form>",
            "<div class=\"w-full bg-gray-2\">",
            "   <p>",
            "       We should load <strong>",
            page.pictures.len,
            "       </strong> pictures here.",
            "   </p>",
            "</div>",
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
