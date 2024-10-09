const std = @import("std");
const libs = @import("libs.zig");
const gocv_build_options = &[_][]const u8{ "-Wall", "-Wextra", "--std=c++11", "-fPIC" };

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gocv_dep = b.dependency("gocv", .{
        .target = target,
        .optimize = optimize,
    });
    const gocv_path = gocv_dep.path(".");

    const opencv_info = libs.getOpenCVInfo(b, contrib_files, cuda_files) catch |err| {
        std.debug.print("Failed to get OpenCV info: {s}\n", .{@errorName(err)});
        return;
    };

    if (!opencv_info.installed) {
        std.debug.print("OpenCV not found, skipping build\n", .{});
        return;
    }

    std.debug.print("OpenCV version: {s} found\n", .{opencv_info.version});

    var core_lib: ?*std.Build.Step.Compile = null;
    var contrib_lib: ?*std.Build.Step.Compile = null;
    var cuda_lib: ?*std.Build.Step.Compile = null;

    core_lib = libs.buildStaticLib(b, .{
        .libname = "opencv",
        .target = target,
        .optimize = optimize,
        .source_dir = gocv_path,
        .cflags = gocv_build_options,
    }, core_files);

    if (opencv_info.has_contrib) {
        contrib_lib = libs.buildStaticLib(b, .{
            .libname = "opencv_contrib",
            .target = target,
            .optimize = optimize,
            .source_dir = .{ .cwd_relative = b.pathJoin(&.{ gocv_path.getPath(b), "/contrib" }) },
            .cflags = gocv_build_options,
        }, contrib_files);
    } else {
        std.debug.print("Contrib modules not found, skipping contrib build\n", .{});
    }

    if (opencv_info.has_cuda) {
        cuda_lib = libs.buildStaticLib(b, .{
            .libname = "opencv_cuda",
            .target = target,
            .optimize = optimize,
            .source_dir = .{ .cwd_relative = b.pathJoin(&.{ gocv_path.getPath(b), "/cuda" }) },
            .cflags = gocv_build_options,
        }, cuda_files);
    } else {
        std.debug.print("CUDA modules not found, skipping CUDA build\n", .{});
    }

    const module = libs.buildModule(b, .{
        .modname = "opencv",
        .source_file = b.path("src/opencv.zig"),
        .source_dir = gocv_path,
    });

    const examples = [_]Program{
        .{
            .name = "hello",
            .path = "examples/hello/main.zig",
            .desc = "Show Webcam",
        },
        .{
            .name = "version",
            .path = "examples/version/main.zig",
            .desc = "Print OpenCV Version",
        },
        .{
            .name = "show_image",
            .path = "examples/showimage/main.zig",
            .desc = "Show Image Demo",
        },
        .{
            .name = "face_detection",
            .path = "examples/facedetect/main.zig",
            .desc = "Face Detection Demo",
        },
        .{
            .name = "face_blur",
            .path = "examples/faceblur/main.zig",
            .desc = "Face Detection and Blur Demo",
        },
        .{
            .name = "dnn_detection",
            .path = "examples/dnndetection/main.zig",
            .desc = "DNN Detection Demo",
        },
        .{
            .name = "saveimage",
            .path = "examples/saveimage/main.zig",
            .desc = "Save Image Demo",
        },
        .{
            .name = "detail_enhance",
            .path = "examples/detail_enhance/main.zig",
            .desc = "Detail Enhanced Image Demo",
        },
    };

    for (examples) |example| {
        const example_exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
        });

        example_exe.root_module.addImport("opencv", module);
        if (core_lib) |lib| example_exe.linkLibrary(lib);
        if (contrib_lib) |lib| example_exe.linkLibrary(lib);
        if (cuda_lib) |lib| example_exe.linkLibrary(lib);

        libs.linkSystemLibraries(example_exe);
        b.installArtifact(example_exe);
    }
}

const core_files = &[_][]const u8{
    "aruco.cpp",
    "asyncarray.cpp",
    "calib3d.cpp",
    "core.cpp",
    "dnn.cpp",
    "features2d.cpp",
    "highgui.cpp",
    "imgcodecs.cpp",
    "imgproc.cpp",
    "objdetect.cpp",
    "persistence_filenode.cpp",
    "persistence_filestorage.cpp",
    "photo.cpp",
    "svd.cpp",
    "version.cpp",
    "video.cpp",
    "videoio.cpp",
};

const contrib_files = &[_][]const u8{
    "bgsegm.cpp",
    "face.cpp",
    "freetype.cpp",
    "img_hash.cpp",
    "tracking.cpp",
    "wechat_qrcode.cpp",
    "xfeatures2d.cpp",
    "ximgproc.cpp",
    "xphoto.cpp",
};

const cuda_files = &[_][]const u8{
    "arithm.cpp",
    "bgsegm.cpp",
    "core.cpp",
    "cuda.cpp",
    "filters.cpp",
    "imgproc.cpp",
    "objdetect.cpp",
    "optflow.cpp",
    "warping.cpp",
};

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
    fstage1: bool = false,
};
