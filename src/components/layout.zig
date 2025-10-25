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
    []const u8,
    @TypeOf(children),
    []const u8,
    []const u8,
    []const u8,
}) {
    return .{
        "<!DOCTYPE html>",
        "<html lang=\"pt-BR\">",
        "<head>",
        "  <meta charset=\"UTF-8\">",
        "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
        "  <title>" ++ title ++ "</title>",
        "  <link rel=\"stylesheet\" href=\"/public/generated.css\">",
        "</head>",
        "<body class=\"m-0 text-base bg-gray-1 text-green-1 font-sans\">",
        "  <div class=\"container mx-auto\">",
        children,
        "  </div>",
        "</body>",
        "</html>",
    };
}
