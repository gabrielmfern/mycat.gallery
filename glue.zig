const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

pub const Predicate = fn (request: *http.Server.Request) bool;

fn matchesPattern(target: []const u8, pattern: []const u8) bool {
    var target_pos: usize = 0;
    var pattern_pos: usize = 0;

    while (pattern_pos < pattern.len) {
        if (pattern_pos < pattern.len and pattern[pattern_pos] == '[') {
            const bracket_end = std.mem.indexOfScalarPos(u8, pattern, pattern_pos, ']') orelse return false;
            const param_name = pattern[pattern_pos + 1 .. bracket_end];

            if (std.mem.startsWith(u8, param_name, "...")) {
                return true;
            }

            const next_pattern_pos = bracket_end + 1;
            if (next_pattern_pos >= pattern.len) {
                return target_pos < target.len;
            }

            const next_char = pattern[next_pattern_pos];
            const next_pos = std.mem.indexOfScalarPos(u8, target, target_pos, next_char) orelse target.len;

            if (next_pos == target_pos) return false;

            target_pos = next_pos;
            pattern_pos = next_pattern_pos;
        } else {
            if (target_pos >= target.len or target[target_pos] != pattern[pattern_pos]) {
                return false;
            }
            target_pos += 1;
            pattern_pos += 1;
        }
    }

    return target_pos == target.len;
}

test "matchesPattern" {
    try std.testing.expect(matchesPattern("/", "/"));
    try std.testing.expect(!matchesPattern("/some-route", "/"));
    try std.testing.expect(matchesPattern("/my-route", "/my-route"));
    try std.testing.expect(!matchesPattern("/some-route", "/my-route"));
    try std.testing.expect(!matchesPattern("/my-route/something-else", "/my-route"));

    try std.testing.expect(matchesPattern("/pictures/123", "/pictures/[id]"));
    try std.testing.expect(matchesPattern("/pictures/abc", "/pictures/[id]"));
    try std.testing.expect(!matchesPattern("/pictures", "/pictures/[id]"));
    try std.testing.expect(!matchesPattern("/pictures/", "/pictures/[id]"));

    try std.testing.expect(matchesPattern("/assets/style.css", "/assets/[...name]"));
    try std.testing.expect(matchesPattern("/assets/js/app.js", "/assets/[...name]"));
    try std.testing.expect(matchesPattern("/assets/images/logo.png", "/assets/[...name]"));
    try std.testing.expect(!matchesPattern("/asset/images/logo.png", "/assets/[...name]"));

    try std.testing.expect(matchesPattern("/api/users/123/posts", "/api/users/[id]/posts"));
    try std.testing.expect(!matchesPattern("/api/users/posts", "/api/users/[id]/posts"));
}


pub fn predicate_from(
    path: []const u8,
) Predicate {
    const route_pattern = path["./app".len .. path.len - "route.zig".len];

    return (struct {
        const pattern = route_pattern;

        fn predicate(request: *http.Server.Request) bool {
            return matchesPattern(request.head.target, pattern);
        }
    }).predicate;
}

pub const Route = struct {
    handler: fn (request: *http.Server.Request) anyerror!void,
    predicate: Predicate,

    pub fn from(module: anytype, path: []const u8) Route {
        return Route{
            .predicate = predicate_from(path),
            .handler = @field(module, "handler"),
        };
    }
};

// Anything better to name this?
const StringBuilder = struct {
    allocator: std.mem.Allocator,

    string: []u8,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .string = try allocator.alloc(u8, 0),
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.string);
    }

    fn write(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const previous_len = self.string.len;
        self.string = try self.allocator.realloc(
            self.string,
            previous_len + @as(usize, @intCast(std.fmt.count(fmt, args))),
        );
        _ = try std.fmt.bufPrint(
            self.string[previous_len..],
            fmt,
            args,
        );
    }
};

fn write_node(node: anytype, builder: *StringBuilder) !void {
    const Node = @TypeOf(node);
    const node_type_info = @typeInfo(Node);

    if (node_type_info == .pointer and node_type_info.pointer.size == .slice and node_type_info.pointer.child == u8) {
        try builder.write("{s}", .{node});
        return;
    }

    if (node_type_info == .pointer) {
        const child_type_info = @typeInfo(node_type_info.pointer.child);

        if (child_type_info == .array and child_type_info.array.child == u8) {
            try builder.write("{s}", .{node});
            return;
        }

        if (node_type_info.pointer.size == .slice) {
            for (node) |child| {
                try write_node(child, builder);
            }
            return;
        }

        try write_node(node.*, builder);
        return;
    }

    if (node_type_info == .@"struct") {
        try write_nodes(node, builder);
        return;
    }

    if (node_type_info == .int or node_type_info == .float) {
        try builder.write("{d:.1}", .{node});
        return;
    }

    if (node_type_info == .bool) {
        try builder.write("{s}", .{if (node) "true" else "false"});
        return;
    }

    @compileError("Unsupported type to interpolate into HTML: " ++ @typeName(Node));
}

fn write_nodes(nodes: anytype, builder: *StringBuilder) !void {
    const Nodes = @TypeOf(nodes);
    const nodes_type_info = @typeInfo(Nodes);
    if (nodes_type_info != .@"struct") {
        @compileError("Expected a struct type for HTML nodes");
    }

    inline for (nodes) |node| {
        try write_node(node, builder);
    }
}

pub fn html(nodes: anytype, allocator: std.mem.Allocator) ![]u8 {
    var string_builder = try StringBuilder.init(allocator);
    errdefer string_builder.deinit();

    try write_nodes(nodes, &string_builder);

    return string_builder.string;
}

test "html" {
    const string = try html(.{
        "<!DOCTYPE html>",
        "<html>",
        "<head>",
        "<title>Test Page</title>",
        "</head>",
        "<body>",
        "<h1>Hello, World!</h1>",
        "<p>This is a test page.</p>",
        "</body>",
        "</html>",
    }, std.testing.allocator);
    defer std.testing.allocator.free(string);

    const expected = "<!DOCTYPE html><html><head><title>Test Page</title></head><body><h1>Hello, World!</h1><p>This is a test page.</p></body></html>";

    try std.testing.expectEqualSlices(u8, expected, string);
}

pub fn readBody(
    request: *http.Server.Request,
    allocator: std.mem.Allocator,
) !?[]const u8 {
    if (request.head.content_length) |content_length| {
        const reader = try request.reader();
        const body = try allocator.alloc(
            u8,
            content_length,
        );
        _ = try reader.readAll(body);

        return body;
    } else {
        return null;
    }
}

pub const MultiPartForm = struct {
    allocator: Allocator,
    fields: std.ArrayList(MultiPartField),
    body: []const u8,

    pub fn parse(allocator: Allocator, request: *std.http.Server.Request) !@This() {
        var fields = std.ArrayList(MultiPartField).init(allocator);
        errdefer fields.deinit();
        const body = try readBody(request, allocator) orelse return error.NoBody;
        errdefer allocator.free(body);

        const content_type = request.head.content_type orelse return error.NoContentType;
        if (!std.ascii.startsWithIgnoreCase(content_type, "multipart/form-data")) {
            return error.NotMultiPartFormData;
        }

        const boundary = extract_boundary(content_type) orelse return error.InvalidBoundary;

        var boundary_buf: [74]u8 = undefined;
        boundary_buf[0] = '-';
        boundary_buf[1] = '-';
        @memcpy(boundary_buf[2 .. 2 + boundary.len], boundary);
        const full_boundary = boundary_buf[0 .. 2 + boundary.len];

        var entry_it = std.mem.splitSequence(u8, body, full_boundary);

        _ = entry_it.next();

        while (entry_it.next()) |entry| {
            if (entry.len >= 4 and std.mem.startsWith(u8, entry, "--\r\n")) {
                break;
            }

            if (entry.len < 2 or entry[0] != '\r' or entry[1] != '\n') continue;
            const field_data = entry[2..];

            if (try parse_field(field_data)) |field| {
                try fields.append(field);
            }
        }

        return .{
            .allocator = allocator,
            .fields = fields,
            .body = body,
        };
    }

    pub fn deinit(self: @This()) void {
        self.fields.deinit();
        self.allocator.free(self.body);
    }
};

pub const MultiPartField = struct {
    name: []const u8,
    filename: ?[]const u8,
    content: []const u8,
};

fn extract_boundary(content_type: []const u8) ?[]const u8 {
    const boundary_prefix = "boundary=";
    const start = std.mem.indexOf(u8, content_type, boundary_prefix) orelse return null;
    var boundary = content_type[start + boundary_prefix.len ..];

    if (boundary.len > 0 and boundary[0] == '"') {
        boundary = boundary[1..];
        if (std.mem.indexOf(u8, boundary, "\"")) |end| {
            boundary = boundary[0..end];
        }
    } else {
        if (std.mem.indexOf(u8, boundary, ";")) |end| {
            boundary = boundary[0..end];
        }
    }

    return if (boundary.len > 0 and boundary.len <= 70) boundary else null;
}

fn parse_field(field_data: []const u8) !?MultiPartField {
    var pos: usize = 0;
    var name: ?[]const u8 = null;
    var filename: ?[]const u8 = null;

    while (pos < field_data.len) {
        const line_end = std.mem.indexOfScalarPos(u8, field_data, pos, '\n') orelse break;
        const line = field_data[pos..line_end];
        pos = line_end + 1;

        const clean_line = if (line.len > 0 and line[line.len - 1] == '\r')
            line[0 .. line.len - 1]
        else
            line;

        if (clean_line.len == 0) break;

        if (std.ascii.startsWithIgnoreCase(clean_line, "content-disposition:")) {
            const value = std.mem.trim(u8, clean_line["content-disposition:".len..], " \t");
            if (std.ascii.startsWithIgnoreCase(value, "form-data;")) {
                const attrs = value["form-data;".len..];

                var attr_it = std.mem.splitSequence(u8, attrs, ";");
                while (attr_it.next()) |attr| {
                    const clean_attr = std.mem.trim(u8, attr, " \t");
                    if (std.mem.startsWith(u8, clean_attr, "name=")) {
                        name = parse_quoted_value(clean_attr["name=".len..]);
                    } else if (std.mem.startsWith(u8, clean_attr, "filename=")) {
                        filename = parse_quoted_value(clean_attr["filename=".len..]);
                    }
                }
            }
        }
    }

    const field_name = name orelse return null;

    var content = field_data[pos..];
    if (content.len >= 2 and content[content.len - 2] == '\r' and content[content.len - 1] == '\n') {
        content = content[0 .. content.len - 2];
    }

    return MultiPartField{
        .name = field_name,
        .filename = filename,
        .content = content,
    };
}

fn parse_quoted_value(value: []const u8) []const u8 {
    var result = std.mem.trim(u8, value, " \t");
    if (result.len >= 2 and result[0] == '"' and result[result.len - 1] == '"') {
        result = result[1 .. result.len - 1];
    }
    return result;
}
