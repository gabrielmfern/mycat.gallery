const std = @import("std");
const sqlite = @import("sqlite");
const uuid = @import("uuid");

pub const Picture = struct {
    favorite: bool,
    uri: [:0]u8,
};

pub const PicturePage = struct {
    pictures: []Picture,
    page: usize,
    last_page: usize,
};

const Self = @This();

database: sqlite.Db,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    var database = try sqlite.Db.init(.{
        .mode = .{ .File = "database.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });
    try database.exec(
        \\CREATE TABLE 
        \\  IF NOT EXISTS 
        \\pictures (
        \\  id INTEGER PRIMARY KEY, 
        \\  favorite BOOLEAN, 
        \\  uri TEXT, 
        \\  taken_at INTEGER
        \\);
    ,
        .{},
        .{},
    );
    return .{
        .database = database,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.database.deinit();
}

pub const page_size = 24;

pub fn get_page(self: *Self, page: usize) !PicturePage {
    var statement = try self.database.prepare(
        \\SELECT favorite, uri 
        \\FROM pictures 
        \\ORDER BY taken_at DESC 
        \\LIMIT ? 
        \\OFFSET ?;
    );
    defer statement.deinit();

    const pictures: []Picture = try statement.all(
        Picture,
        self.allocator,
        .{},
        .{
            .limit = page_size,
            .offset = (page - 1) * page_size,
        },
    );

    var count_statement = try self.database.prepare(
        \\SELECT COUNT(*) FROM pictures;
    );
    defer count_statement.deinit();

    const total_picture_count: usize = (try count_statement.one(
        usize,
        .{},
        .{},
    )) orelse return error.CouldNotCountPictures;
    const page_count = @divFloor(total_picture_count, @as(usize, @intCast(page_size)));
    return .{
        .pictures = pictures,
        .page = page,
        .last_page = page_count,
    };
}

pub fn post(self: *Self, bytes: []const u8, taken_at: i32, file_extension: []const u8) !void {
    std.fs.cwd().makeDir("pictures") catch |err|
        if (err != error.PathAlreadyExists) return err;

    const id = uuid.v7.new();
    const uri = try std.fmt.allocPrint(self.allocator, "pictures/{d}.{s}", .{ id, file_extension });
    defer self.allocator.free(uri);

    const image = try std.fs.cwd().createFile(uri, .{ .exclusive = true });
    defer image.close();
    try image.writeAll(bytes);

    var statement = try self.database.prepare(
        \\INSERT INTO pictures (favorite, uri, taken_at) 
        \\VALUES (?, ?, ?);
    );
    defer statement.deinit();

    try statement.exec(.{}, .{
        .favorite = false,
        .uri = uri,
        .taken_at = taken_at,
    });
}
