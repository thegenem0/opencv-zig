const std = @import("std");

const gocv_source_files = [_][]const u8{
    "core.cpp",
    "asyncarray.cpp",
    "calib3d.cpp",
    "dnn.cpp",
    "features2d.cpp",
    "highgui.cpp",
    "imgcodecs.cpp",
    "imgproc.cpp",
    "objdetect.cpp",
    "photo.cpp",
    "svd.cpp",
    "version.cpp",
    "video.cpp",
    "videoio.cpp",
};

const gocv_build_options = &[_][]const u8{ "-Wall", "-Wextra", "--std=c++11", "-fPIC" };

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gocv_dep = b.dependency("gocv", .{
        .target = target,
        .optimize = optimize,
    });
    const gocv_path = gocv_dep.path(".");

    const opencv_zig = b.addStaticLibrary(.{
        .name = "opencv",
        .target = target,
        .optimize = optimize,
    });

    inline for (gocv_source_files) |file| {
        const c_file_path = b.pathJoin(&.{ gocv_path.getPath(b), file });
        std.debug.print("adding {s}\n", .{c_file_path});
        opencv_zig.addCSourceFile(.{
            .file = .{ .cwd_relative = c_file_path },
            .flags = gocv_build_options,
        });
    }

    linkSystemLibraries(opencv_zig);

    std.debug.print("adding include path {s}\n", .{gocv_path.getPath(b)});
    opencv_zig.addIncludePath(gocv_path);

    std.debug.print("installing headers\n", .{});
    b.installArtifact(opencv_zig);

    const module = b.addModule("opencv_c", .{
        .root_source_file = b.path("src/opencv.zig"),
    });

    std.debug.print("adding include path {s}\n", .{gocv_path.getPath(b)});
    module.addIncludePath(gocv_path);

    const example = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("examples/hello/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    std.debug.print("adding import opencv\n", .{});
    example.root_module.addImport("opencv", module);

    std.debug.print("linking library opencv\n", .{});
    example.linkLibrary(opencv_zig);
    linkSystemLibraries(example);

    b.installArtifact(example);
}

fn linkSystemLibraries(step: *std.Build.Step.Compile) void {
    switch (step.rootModuleTarget().os.tag) {
        .windows => {
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include" });
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include/c++/12.2.0" });
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include/c++/12.2.0/x86_64-w64-mingw32" });
            step.addLibraryPath(.{ .cwd_relative = "c:/msys64/mingw64/lib" });
            step.addIncludePath(.{ .cwd_relative = "c:/opencv/build/install/include" });
            step.addLibraryPath(.{ .cwd_relative = "c:/opencv/build/install/x64/mingw/staticlib" });

            step.linkSystemLibrary("opencv4");
            step.linkSystemLibrary("stdc++.dll");
            step.linkSystemLibrary("unwind");
            step.linkSystemLibrary("m");
            step.linkSystemLibrary("c");
        },
        else => {
            step.linkSystemLibrary("stdc++");
            step.linkSystemLibrary("opencv4");
            step.linkSystemLibrary("unwind");
            step.linkSystemLibrary("m");
            step.linkSystemLibrary("c");
        },
    }
}
