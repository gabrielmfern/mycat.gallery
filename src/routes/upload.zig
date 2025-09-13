const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../main.zig").use_allocator;
const use_database = @import("../main.zig").use_database;

const globals_css = @embedFile("./public/globals.css");

pub const predicate = glue.Predicates.exact(
    "/upload",
    http.Method.POST,
);

pub fn handler(request: *http.Server.Request) anyerror!void {
    const allocator = use_allocator();
    const database = use_database();

    const multi_part_form_data = try glue.MultiPartForm.parse(allocator, request);
    defer multi_part_form_data.deinit();

    for (multi_part_form_data.fields.items) |field| {
        if (std.mem.eql(u8, field.name, "picture")) {
            var splitIterator = std.mem.splitBackwardsSequence(u8, field.filename, ".");
            const extension = splitIterator.first();
            std.log.debug(
                "Received picture: {s} ({d} bytes, extension: {s})",
                .{
                    field.filename orelse "unknown",
                    field.content.len,
                    extension,
                },
            );
            try database.add(
                field.content,
                0, // TODO: get the time in which the picture was taken from the image's metadata and write it here
                extension,
            );
        } else {
            std.log.debug("Received unkown field in form: {s}", .{field.name});
        }
    }

    try request.respond(
        "Saved the new picture successfully!",
        .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
            },
        },
    );
}
