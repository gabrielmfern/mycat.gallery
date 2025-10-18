const glue = @import("glue");
pub const routes: []const glue.Route = &.{
   glue.Route.from(@import("./app/assets/[...path]/route.zig"), "./app/assets/[...path]/route.zig"),
   glue.Route.from(@import("./app/upload/route.zig"), "./app/upload/route.zig"),
   glue.Route.from(@import("./app/route.zig"), "./app/route.zig"),
   glue.Route.from(@import("./app/pictures/[id]/route.zig"), "./app/pictures/[id]/route.zig")
};