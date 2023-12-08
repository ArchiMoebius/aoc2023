const std = @import("std");

const targets: []const std.zig.CrossTarget = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn package(b: *std.Build, exe: *std.build.Step.Compile, t: std.zig.CrossTarget) !void {
        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        });

        b.getInstallStep().dependOn(&target_output.step);

        return;
}

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    for (targets) |t| {
        // try package(b, b.addExecutable(.{
        //     .name = "part_one",
        //     .root_source_file = .{ .path = "part_one.zig" },
        //     .target = t,
        //     .optimize = optimize,
        // }), t);

        // try package(b, b.addExecutable(.{
        //     .name = "part_two",
        //     .root_source_file = .{ .path = "part_two.zig" },
        //     .target = t,
        //     .optimize = optimize,
        // }), t);

        try package(b, b.addExecutable(.{
            .name = "part_two_thoughtful",
            .root_source_file = .{ .path = "part_two_thoughtful.zig" },
            .target = t,
            .optimize = optimize,
        }), t);
    }
}