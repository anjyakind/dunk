//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const libs = @import("libs/libs.zig");
const actions = libs.actions;
const arg = libs.utils.arg;
const config = libs.utils.config;
const payload = libs.utils.payload;

const actionArg = arg.Argument{ .name = "action", .dest = "action", .help = "Action to be performed e.g wipe, remove, restore, delete", .required = true };

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    // try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    // try bw.flush(); // Don't forget to flush!

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    std.debug.print("{s} {}", .{ args, args.len });

    var argParser = arg.ArgParser().init(allocator, .{ .programName = "Dunk" });
    defer argParser.deinit();

    try argParser.addArg(actionArg);

    const action = argParser.getParsedArgs(actionArg.dest);
    const dunkConfig = config.DunkConfig{};

    var errPayload = payload.ErrPayload(dunkConfig).init(.{ .allocator = allocator, .payload = dunkConfig });
    defer errPayload.deinit();

    if (action) |validAction| {
        switch (validAction) {
            .string => |strVal| {
                if (std.mem.eql(u8, strVal, actions.delete.DeleteActionName)) {
                    actions.delete.DeleteAction.run(args[2..], allocator, &errPayload) catch {
                        std.log.err(errPayload.getErrMsg(), .{});
                    };
                } else {
                    return;
                }
            },
            .boolean => unreachable,
        }
    } else {
        try std.io.getStdErr().writer().print("Action positional argument required", .{});
    }
}

test "hello" {
    const hello = "hello";
    try std.testing.expectEqual("hello", hello);
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("dunk_lib");

test {
    _ = libs;
}
