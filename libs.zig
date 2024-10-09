const std = @import("std");

const LibParams = struct {
    libname: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    source_dir: std.Build.LazyPath,
    cflags: []const []const u8,
};

const ModParams = struct {
    modname: []const u8,
    source_file: std.Build.LazyPath,
    source_dir: std.Build.LazyPath,
};

const OpenCVInfo = struct {
    installed: bool,
    version: []const u8,
    include_path: []const u8,
    lib_path: []const u8,
    cflags: []const []const u8,
    libs: []const []const u8,
    has_contrib: bool,
    has_cuda: bool,
};

pub fn buildStaticLib(b: *std.Build, params: LibParams, comptime source_files: []const []const u8) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = params.libname,
        .target = params.target,
        .optimize = params.optimize,
    });

    inline for (source_files) |file| {
        const c_file_path = b.pathJoin(&.{ params.source_dir.getPath(b), file });
        lib.addCSourceFile(.{
            .file = .{ .cwd_relative = c_file_path },
            .flags = params.cflags,
        });
    }

    linkSystemLibraries(lib);

    lib.addIncludePath(params.source_dir);

    b.installArtifact(lib);

    return lib;
}

pub fn buildModule(b: *std.Build, params: ModParams) *std.Build.Module {
    const module = b.addModule(params.modname, .{ .root_source_file = params.source_file });

    module.addIncludePath(params.source_dir);

    return module;
}

pub fn linkSystemLibraries(step: *std.Build.Step.Compile) void {
    switch (step.rootModuleTarget().os.tag) {
        .windows => {
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include" });
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include/c++/12.2.0" });
            step.addIncludePath(.{ .cwd_relative = "c:/msys64/mingw64/include/c++/12.2.0/x86_64-w64-mingw32" });
            step.addLibraryPath(.{ .cwd_relative = "c:/msys64/mingw64/lib" });
            step.addIncludePath(.{ .cwd_relative = "c:/opencv/build/install/include" });
            step.addLibraryPath(.{ .cwd_relative = "c:/opencv/build/install/x64/mingw/staticlib" });

            step.linkLibC();
            step.linkLibCpp();
            step.linkSystemLibrary("opencv4");
            step.linkSystemLibrary("unwind");
            step.linkSystemLibrary("m");
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

pub fn getOpenCVInfo(b: *std.Build, comptime contrib_files: []const []const u8, comptime cuda_files: []const []const u8) !OpenCVInfo {
    var result = OpenCVInfo{
        .installed = false,
        .version = "",
        .include_path = "",
        .lib_path = "",
        .cflags = &[_][]const u8{},
        .libs = &[_][]const u8{},
        .has_contrib = false,
        .has_cuda = false,
    };

    const modversion_result = try runShellCmd(b.allocator, &[_][]const u8{ "pkg-config", "--modversion", "opencv4" });

    if (modversion_result.len == 0) {
        return result;
    }

    result.version = try b.allocator.dupe(u8, std.mem.trimRight(u8, modversion_result, " \n"));
    result.installed = true;

    const cflags_result = try runShellCmd(b.allocator, &[_][]const u8{ "pkg-config", "--cflags", "opencv4" });

    if (cflags_result.len != 0) {
        var cflags_list = std.ArrayList([]const u8).init(b.allocator);
        var cflags_iter = std.mem.split(u8, cflags_result, " ");
        while (cflags_iter.next()) |flag| {
            if (std.mem.startsWith(u8, flag, "-I")) {
                result.include_path = flag[2..];
            }
            try cflags_list.append(try b.allocator.dupe(u8, flag));
        }
        result.cflags = try cflags_list.toOwnedSlice();
    }

    const libs_result = try runShellCmd(b.allocator, &[_][]const u8{ "pkg-config", "--libs", "opencv4" });

    if (libs_result.len != 0) {
        var libs_list = std.ArrayList([]const u8).init(b.allocator);
        var libs_iter = std.mem.split(u8, libs_result, " ");
        while (libs_iter.next()) |lib| {
            if (std.mem.startsWith(u8, lib, "-L")) {
                result.lib_path = lib[2..];
            }
            try libs_list.append(try b.allocator.dupe(u8, lib));
        }
        result.libs = try libs_list.toOwnedSlice();
    }

    result.has_contrib = try checkAvailableCVModules(b, contrib_files, libs_result);
    result.has_cuda = try checkAvailableCVModules(b, cuda_files, libs_result);

    return result;
}

fn checkAvailableCVModules(b: *std.Build, comptime files: []const []const u8, libs_result: []const u8) !bool {
    for (files) |file| {
        const trimmed_file = std.mem.trimRight(u8, file, ".cpp");
        const check_flag = try std.fmt.allocPrint(b.allocator, "-lopencv_{s}", .{trimmed_file});
        if (std.mem.indexOf(u8, libs_result, check_flag) == null) {
            return false;
        }
    }
    return true;
}

pub fn runShellCmd(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    }) catch |err| {
        std.debug.print("pkg-config failed: {any}\n", .{err});
        return error.PkgConfigFailed;
    };

    if (result.term != .Exited) {
        std.debug.print("pkg-config failed with exit code {d}\n", .{@intFromEnum(result.term)});
        return error.PkgConfigFailed;
    }

    if (result.stderr.len > 0) {
        std.debug.print("pkg-config stderr:\n{s}\n", .{result.stderr});
        return error.PkgConfigFailed;
    }

    if (result.stdout.len == 0) {
        std.debug.print("pkg-config returned no output\n", .{});
        return error.PkgConfigFailed;
    }

    return result.stdout;
}
