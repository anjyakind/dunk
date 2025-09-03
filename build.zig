const std = @import("std");
const zon: ZONData = @import("build.zig.zon");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // options
    const projectInfoOptions = generateProjectInfoOptions(b) catch {
        std.log.err("Build Error: An error occured while generating projectInfo Options", .{});
        return;
    };
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // modules
    // utils Module
    const utilsMod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("src/utils/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // args module
    const argsMod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("src/args/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // actions Module
    const actionsMod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("src/actions/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    actionsMod.addImport("utils", utilsMod);

    // main module
    const mainMod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    mainMod.addImport("utils", utilsMod);
    mainMod.addImport("actions", actionsMod);
    mainMod.addImport("args", argsMod);
    mainMod.addOptions("projectInfo", projectInfoOptions);

    // all self modules
    const modules = [_]struct { module: *std.Build.Module, name: []const u8 }{
        .{
            .module = mainMod,
            .name = "main",
        },
        .{
            .module = actionsMod,
            .name = "actions",
        },
        .{
            .module = utilsMod,
            .name = "utils",
        },
        .{
            .module = argsMod,
            .name = "args",
        },
    };

    // main executable
    const exe: *std.Build.Step.Compile = b.addExecutable(.{
        .name = "dunk",
        .root_module = mainMod,
        .optimize = optimize,
    });

    // install executable
    b.installArtifact(exe);

    // create run step (only creates an object still need to add it to a step)
    const run_exe: *std.Build.Step.Run = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step: *std.Build.Step = b.step("run", "Run application");
    run_step.dependOn(&run_exe.step);

    const test_step: *std.Build.Step = b.step("test", "Run unit tests");

    for (modules) |module| {
        const unit_test: *std.Build.Step.Compile = b.addTest(.{
            .name = module.name,
            .root_module = module.module,
            .target = target,
            .optimize = optimize,
        });

        const runUnitTest = b.addRunArtifact(unit_test);
        test_step.dependOn(&runUnitTest.step);
    }
}

fn generateProjectInfoOptions(b: *std.Build) !*std.Build.Step.Options {
    const projectInfoOptions = b.addOptions();
    projectInfoOptions.addOption(std.SemanticVersion, "version", try std.SemanticVersion.parse(zon.version));
    return projectInfoOptions;
}

const ZONData = struct {
    name: @Type(.enum_literal),
    version: []const u8,
    fingerprint: u64,
    minimum_zig_version: []const u8,
    dependencies: struct {},
    paths: []const []const u8,
};
