const std = @import("std");
const glue = @import("glue");

pub fn layout(
    comptime title: []const u8,
    children: anytype,
) std.meta.Tuple(&.{
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    []const u8,
    @TypeOf(children),
    []const u8,
    []const u8,
}) {
    return .{
        "<!DOCTYPE html>",
        "<html lang=\"en\">",
        "<head>",
        "  <meta charset=\"UTF-8\">",
        "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
        "  <title>" ++ title ++ "</title>",
        "  <link rel=\"stylesheet\" href=\"/public/globals.css\">",
        "</head>",
        "<body>",
        children,
        "</body>",
        "</html>",
    };
}
