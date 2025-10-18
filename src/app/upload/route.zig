const std = @import("std");
const http = std.http;
const glue = @import("glue");

const use_allocator = @import("../../main.zig").use_allocator;
const use_database = @import("../../main.zig").use_database;

const globals_css = @embedFile("./public/globals.css");

pub fn handler(request: *http.Server.Request) anyerror!void {
    if (request.head.method == .POST) {
        const allocator = use_allocator();
        var database = try use_database();
        const multi_part_form_data = glue.MultiPartForm.parse(allocator, request) catch |err| {
            std.log.err("Failed to parse multipart form data: {any}", .{err});
            try request.respond(
                "Failed to parse multipart form data",
                .{
                    .status = .bad_request,
                    .extra_headers = &.{
                        .{ .name = "Content-Type", .value = "text/plain; charset=UTF-8" },
                    },
                },
            );
            return;
        };

        for (multi_part_form_data.fields.items) |field| {
            if (std.mem.eql(u8, field.name, "picture")) {
                const filename = field.filename orelse {
                    try request.respond(
                        "No filename provided for the picture to upload",
                        .{
                            .status = .bad_request,
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
}
