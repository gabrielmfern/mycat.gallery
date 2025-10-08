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
    const multi_part_form_data = glue.MultiPartForm.parse(allocator, request) catch |err| {
        std.log.err("Failed to parse multipart form data: {any}", .{err});
        try request.respond(
            "Failed to parse multipart form data",
            .{
                .status = .badRequest,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                },
            },
        );
        return;
    };
    defer multi_part_form_data.deinit();

    for (multi_part_form_data.fields.items) |field| {
        if (std.mem.eql(u8, field.name, "picture")) {
            const filename = field.filename orelse {
                try request.respond(
                    "No filename provided for the picture to upload",
                    .{
                        .status = .badRequest,
                        .extra_headers = &.{
                            .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                        },
                    },
                );
                return;
            };
            var splitIterator = std.mem.splitBackwardsSequence(
                u8,
                filename,
                ".",
            );
            const extension = splitIterator.first();
            std.log.debug(
                "Received picture: {s} ({d} bytes, extension: {s})",
                .{
                    filename,
                    field.content.len,
                    extension,
                },
            );
            try database.post(
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
