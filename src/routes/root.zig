const std = @import("std");
const http = std.http;
const glue = @import("glue");
const layout = @import("../components/layout.zig").layout;
const logo = @import("../components/logo.zig").logo;

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

    var picture_elements = try allocator.alloc([]const u8, page.pictures.len);
    defer {
        for (picture_elements) |element| {
            allocator.free(element);
        }
        allocator.free(picture_elements);
    }
    for (page.pictures, 0..) |picture, i| {
        picture_elements[i] = try glue.html(.{
            "<div class=\"picture-card\">",
            "   <img",
            "       src=\"", picture.uri, "\"",
            "   />",
            "</div>",
        }, allocator);
    }

    const html = try glue.html(.{
        layout("mycat", .{
            "<div class=\"flex py-4 border-b border-b-gray-2 mb-4\">",
            logo,
            "   <form id=\"submitPictureForm\" class=\"ml-auto w-fit\" method=\"POST\" enctype=\"multipart/form-data\">",
            "      <label for=\"picture\" class=\"text-green-1 flex items-center align-middle cursor-pointer\">",
            "          <svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\"><path fill=\"currentColor\" d=\"M18 13h-5v5c0 .55-.45 1-1 1s-1-.45-1-1v-5H6c-.55 0-1-.45-1-1s.45-1 1-1h5V6c0-.55.45-1 1-1s1 .45 1 1v5h5c.55 0 1 .45 1 1s-.45 1-1 1\"/></svg>",
            "          adicionar foto",
            "      </label>",
            "      <input",
            "          id=\"picture\"",
            "          name=\"picture\"",
            "          type=\"file\"",
            "          accept=\"image/heic, image/*\"",
            "          capture=\"environment\"",
            "          class=\"hidden\"",
            "          onchange=\"fetch('/upload', { method: 'post', body: new FormData(submitPictureForm) }).then(() => location.reload())\"",
            "      />",
            "   </form>",
            "</div>",
            "<div class=\"w-full bg-gray-2 flex flex-wrap p-10\">",
            picture_elements,
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
