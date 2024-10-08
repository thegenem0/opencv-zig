const std = @import("std");
const cv = @import("opencv");

pub fn main() anyerror!void {
    var window = try cv.Window.init("Hello");
    defer window.deinit();
    window.setProperty(.fullscreen, .fullscreen);
    while (true) {
        _ = window.waitKey(0);
    }
}
