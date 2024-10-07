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

const c_build_options: []const []const u8 = &.{
    "-Wall",
    "-Wextra",
    "--std=c++11",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opencv_zig = b.addStaticLibrary(.{
        .name = "opencv",
        .root_source_file = b.path("src/opencv.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dep_opencv_c = b.dependency("gocv", .{ .target = target, .optimize = optimize });

    inline for (gocv_source_files) |file| {
        const c_file_path = b.path(b.pathJoin(&.{ "libs/gocv", file }));
        opencv_zig.addCSourceFile(.{
            .file = c_file_path,
            .flags = c_build_options,
        });
    }

    opencv_zig.installHeadersDirectory(dep_opencv_c.path(""), "", .{
        .include_extensions = &.{".h"},
    });

    linkToOpenCV(opencv_zig);

    opencv_zig.linkLibC();

    b.installArtifact(opencv_zig);

    const module = b.addModule("opencv_c_zig", .{
        .root_source_file = b.path("src/opencv.zig"),
    });

    module.addIncludePath(dep_opencv_c.path(""));
}

fn linkToOpenCV(exe: *std.Build.Step.Compile) void {
    switch (exe.rootModuleTarget().os.tag) {
        .windows => {
            exe.addIncludePath(exe.step.owner.path("c:/msys64/mingw64/include"));
            exe.addIncludePath(exe.step.owner.path("c:/msys64/mingw64/include/c++/12.2.0"));
            exe.addIncludePath(exe.step.owner.path("c:/msys64/mingw64/include/c++/12.2.0/x86_64-w64-mingw32"));
            exe.addLibraryPath(exe.step.owner.path("c:/msys64/mingw64/lib"));
            exe.addIncludePath(exe.step.owner.path("c:/opencv/build/install/include"));
            exe.addLibraryPath(exe.step.owner.path("c:/opencv/build/install/x64/mingw/staticlib"));

            exe.linkSystemLibrary("opencv4");
            exe.linkSystemLibrary("stdc++");
            exe.linkSystemLibrary("unwind");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("c");
        },
        else => {
            exe.linkLibCpp();
            exe.linkSystemLibrary("opencv4");
            exe.linkSystemLibrary("unwind");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("c");
        },
    }
}
