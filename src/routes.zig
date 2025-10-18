const glue = @import("glue");
pub const routes: []const glue.Route = &.{
   glue.Route.from(@import("./app/assets/route.zig"), "./app/assets/route.zig"),
   glue.Route.from(@import("./app/upload/route.zig"), "./app/upload/route.zig"),
   glue.Route.from(@import("./app/route.zig"), "./app/route.zig"),
   glue.Route.from(@import("./app/pictures/route.zig"), "./app/pictures/route.zig")
};