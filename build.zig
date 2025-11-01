const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libm3_only = b.option(bool, "libm3", "Build libwasm3 only") orelse false;

    const libwasm3 = b.addLibrary(.{
        .linkage = .static,
        .name = "m3",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .sanitize_c = .off, // fno-sanitize=undefined
        }),
    });
    libwasm3.root_module.addCMacro("d_m3HasTracer", "1");

    const is_wasm = target.result.cpu.arch.isWasm();
    const is_wasi = target.result.os.tag == .wasi;

    if (is_wasm) {
        if (is_wasi) {
            libwasm3.root_module.addCMacro("d_m3HasWASI", "1");
            libwasm3.linkSystemLibrary("wasi-emulated-process-clocks");
        }
    }
    libwasm3.addIncludePath(b.path("source"));
    libwasm3.addCSourceFiles(.{
        .root = b.path("source"),
        .files = &.{
            "m3_api_libc.c",
            "extensions/m3_extensions.c",
            "m3_api_meta_wasi.c",
            "m3_api_tracer.c",
            "m3_api_uvwasi.c",
            "m3_api_wasi.c",
            "m3_bind.c",
            "m3_code.c",
            "m3_compile.c",
            "m3_core.c",
            "m3_env.c",
            "m3_exec.c",
            "m3_function.c",
            "m3_info.c",
            "m3_module.c",
            "m3_parse.c",
        },
        .flags = if (is_wasm)
            &cflags ++ wasm_cflags
        else
            &cflags,
    });
    libwasm3.linkSystemLibrary("m");
    libwasm3.linkLibC();
    b.installArtifact(libwasm3);

    if (!libm3_only) {
        const wasm3 = b.addExecutable(.{
            .name = "wasm3",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        for (libwasm3.root_module.include_dirs.items) |dir| {
            wasm3.addIncludePath(dir.path);
        }

        wasm3.addCSourceFile(.{
            .file = b.path("platforms/app/main.c"),
            .flags = &cflags,
        });

        wasm3.linkLibrary(libwasm3);
        b.installArtifact(wasm3);
    }
}

const cflags = [_][]const u8{
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-Wparentheses",
    "-Wundef",
    "-Wpointer-arith",
    "-Wstrict-aliasing=2",
    "-std=gnu11",
};

const wasm_cflags = [_][]const u8{
    "-Xclang",
    "-target-feature",
    "-Xclang",
    "+tail-call",
};
