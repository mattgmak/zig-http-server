const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const request_mod = b.addModule("request", .{
        .root_source_file = b.path("internal/request/request.zig"),
    });

    const tcplistener_exe = b.addExecutable(.{
        .name = "tcplistener",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cmd/tcplistener/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "request", .module = request_mod },
            },
        }),
    });
    b.installArtifact(tcplistener_exe);
    const run_tcplistener_step = b.step("run-tcplistener", "Run the tcplistener");
    const run_tcplistener = b.addRunArtifact(tcplistener_exe);
    run_tcplistener_step.dependOn(&run_tcplistener.step);
    run_tcplistener.step.dependOn(b.getInstallStep());

    const udpsender_exe = b.addExecutable(.{
        .name = "udpsender",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cmd/udpsender/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // .{ .name = "zig_http_server", .module = mod },
            },
        }),
    });
    b.installArtifact(udpsender_exe);
    const run_udpsender_step = b.step("run-udpsender", "Run the udpsender");
    const run_udpsender = b.addRunArtifact(udpsender_exe);
    run_udpsender_step.dependOn(&run_udpsender.step);
    run_udpsender.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_tcplistener.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const tcplistener_exe_tests = b.addTest(.{
        .root_module = tcplistener_exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_tcplistener_exe_tests = b.addRunArtifact(tcplistener_exe_tests);
    const request_mod_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("internal/request/request.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_request_mod_tests = b.addRunArtifact(request_mod_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tcplistener_exe_tests.step);
    test_step.dependOn(&run_request_mod_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
