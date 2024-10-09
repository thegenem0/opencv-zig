const std = @import("std");
const cv = @import("opencv");

pub fn main() anyerror!void {
    std.debug.print("version:\t{s}\n", .{cv.openCVVersion()});
}
