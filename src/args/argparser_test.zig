const std = @import("std");
const ArgParser = @import("argparser.zig").ArgParser;
const ArgumentValue = @import("argparser.zig").ArgumentValue;

test "Test if init and denit of argparser works" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
}

test "Test if Argparser can detect the right subcommand" {
    const TestSubcommand = enum {
        sub1,
        sub2,
    };
    var argparser = ArgParser(.{ .enumType = TestSubcommand }).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    const argument = [_][]const u8{ "app.exe", "sub2", "--hello", "bye3" };
    try argparser.parseArgs(argument[0..]);
    const possibleSubcommand = argparser.getSubcommand();

    if (possibleSubcommand) |subcommand| {
        try std.testing.expectEqual(TestSubcommand.sub2, subcommand);
        try std.testing.expect(TestSubcommand.sub1 != subcommand);
    } else {
        unreachable;
    }
}

test "Test that the write subcommand argparser is returned for the right subcommand" {
    const TestSubcommand = enum {
        sub1,
        sub2,
    };
    var argparser = ArgParser(.{ .enumType = TestSubcommand }).init(std.testing.allocator, .{ .programName = "Main command" });
    defer argparser.deinit();
    try argparser.createSubcommandParser(TestSubcommand.sub2, .void, .{ .programName = "Subcommand 2" }, struct {
        fn setup(sub2CommandArgParser: *ArgParser(.void)) !void {
            try sub2CommandArgParser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
        }
    }.setup);
    const argument = [_][]const u8{ "app.exe", "sub2", "--hello", "bye3" };
    try argparser.parseArgs(argument[0..]);
    const possibleSubcommand = argparser.getSubcommand();

    if (possibleSubcommand) |subcommand| {
        switch (subcommand) {
            TestSubcommand.sub2 => {
                var sub2CommandArgParser = argparser.getSubcommandParser(subcommand) orelse unreachable;
                try sub2CommandArgParser.parseArgs(argument[1..]);
                const val = sub2CommandArgParser.getParsedArgs("hello") orelse unreachable;
                try std.testing.expectEqual(ArgumentValue{ .string = "bye3" }, val);
            },
            else => {
                unreachable;
            },
        }
    } else {
        unreachable;
    }
}

test "Test that the argparser size increases by one when adding an argument" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    try std.testing.expectEqual(1, argparser.getSize());
}

test "Test that positional arguments can be retrieved (with destination)" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "hello", .required = false, .dest = "dest1" });
    const argument = [_][]const u8{ "app.exe", "hello.cpp", "hello2.cpp" };
    try argparser.parseArgs(argument[0..]);
    const val = argparser.getParsedArgs("dest1") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "hello.cpp" }, val);
}

test "Test that positional arguments can be retrieved (without destination)" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "hello", .required = false });
    const argument = [_][]const u8{ "app.exe", "hello.cpp", "hello2.cpp" };
    try argparser.parseArgs(argument[0..]);
    const val = argparser.getParsedArgs("hello") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "hello.cpp" }, val);
}

test "Test that the argparser does not return an error after parsing" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    const argument = [_][]const u8{ "app.exe", "--hello", "bye2" };
    try argparser.parseArgs(argument[0..]);
}

test "Test that the argparser returns the right destination (if dest field not provided)" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false });
    const argument = [_][]const u8{ "app.exe", "--hello", "bye3" };
    try argparser.parseArgs(&argument);
    const val = argparser.getParsedArgs("--hello") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "bye3" }, val);
}

test "Test that the argparser returns the right destination" {
    var argparser = ArgParser(.void).init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    const argument = [_][]const u8{ "app.exe", "--hello", "bye3" };
    try argparser.parseArgs(&argument);
    const val = argparser.getParsedArgs("hello") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "bye3" }, val);
}
