const std = @import("std");
const http = std.http;

pub const Predicate = fn (request: *const http.Server.Request) bool;

pub const Route = struct {
    predicate: Predicate,
    handler: fn (request: *http.Server.Request) anyerror!void,

    pub fn from(module: anytype) Route {
        return Route{
            .predicate = @field(module, "predicate"),
            .handler = @field(module, "handler"),
        };
    }
};

pub const Predicates = struct {
    pub fn exact(
        comptime expected: []const u8,
        comptime method: http.Method,
    ) Predicate {
        return struct {
            fn predicate(request: *const http.Server.Request) bool {
                return std.mem.eql(u8, request.head.target, expected) and
                    request.head.method == method;
            }
        }.predicate;
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
