const std = @import("std");
const glue = @import("glue");

pub const logo: []const []const u8 = &.{
    "<div class=\"flex gap-2\">",
    "   <img src=\"/assets/logo.svg\" class=\"h-11\" />",
    "   <span class=\"flex flex-col\">",
    "       <span class=\"text-sm text-white\">mycat</span>",
    "       <span class=\"text-xs\">gallery</span>",
    "   </span>",
    "</div>",
};
