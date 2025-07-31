const std = @import("std");

const ArgumentKeyContext = struct {
    const Self = @This();
    pub fn hash(_: Self, key: ArgumentKey) u64 {
        return switch (key) {
            .number => |n| std.hash.int(n),
            .string => |s| std.hash_map.hashString(s),
        };
    }

    pub fn eql(_: Self, key1: ArgumentKey, key2: ArgumentKey) bool {
        return key1.eql(key2);
    }
};

const ArgumentKey = union(enum) {
    string: []const u8,
    number: u32,

    const Self = @This();

    fn eql(self: Self, other: Self) bool {
        switch (self) {
            .string => |s| switch (other) {
                .string => |s2| return std.mem.eql(u8, s, s2),
                else => return false,
            },
            .number => |n| switch (other) {
                .number => |n2| return n == n2,
                else => return false,
            },
        }
        return false;
    }
};

const ArgumentDefault = union(enum) {
    string: []const u8,
    stringArray: [][]const u8,
};

pub const ArgumentType = enum {
    positional,
    flag,
    option,
};

pub const Argument = struct {
    name: []const u8,
    default: ArgumentDefault = .{.string = ""},
    required: bool = true,
    isFlag: bool = false,
    help: []const u8 = "",
    nargs: u32 = 1,
    dest: []const u8 = "",
};

const ArgumentInternal = struct {
    name: []const u8,
    default: ArgumentDefault,
    required: bool,
    type: ArgumentType,
    help: []const u8,
    nargs: u32 = 1,
    dest: []const u8,
};

pub const ArgumentValue = union(enum) {
    string: []const u8,
    boolean: bool,
};
const ArgumentParserConfig = struct {
    description: []const u8 = "",
    programName: []const u8 = "",
    exitOnErr: bool = true,
    prefixChar: u8 = '-',
    usage: []const u8 = "",
};

const ArgParserError = error{
    InValidOption,
};

/// ArgParser type
pub fn ArgParser() type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        arguments: std.HashMap(ArgumentKey, ArgumentInternal, ArgumentKeyContext, std.hash_map.default_max_load_percentage),
        description: []const u8,
        usage: []const u8,
        programName: []const u8,
        exitOnErr: bool,
        prefixChar: u8,
        destinations: std.StringHashMap(ArgumentValue),
        positionalArgSize: u32 = 0,

        /// returns an argpaser initialized with your config
        pub fn init(allocator: std.mem.Allocator, config: ArgumentParserConfig) Self {
            return Self{
                .allocator = allocator,
                .arguments = std.HashMap(ArgumentKey, ArgumentInternal, ArgumentKeyContext, std.hash_map.default_max_load_percentage).init(allocator),
                .destinations = std.StringHashMap(ArgumentValue).init(allocator),
                .programName = config.programName,
                .exitOnErr = config.exitOnErr,
                .prefixChar = config.prefixChar,
                .description = config.description,
                .usage = config.usage,
            };
        }

        /// parses arguments and initializes destinations so that values
        /// could be returned
        pub fn parseArgs(self: *Self, args: []const []const u8) !void {
            self.destinations.clearRetainingCapacity();
            var positionalArg: u8 = 0;
            var i: usize = 0;

            while (i < args.len) {
                const currArg = args[i];
                // long form options
                if (currArg.len > 2 and std.mem.eql(u8, currArg[0..2], &[2]u8{ self.prefixChar, self.prefixChar })) {
                    const arg = self.arguments.get(.{ .string = currArg });

                    if (arg) |validArg| {
                        // for flags e.g --noColor
                        const validKey = if (validArg.dest.len == 0) currArg else validArg.dest;
                        if (validArg.type == ArgumentType.flag) {
                            try self.destinations.put(validKey, .{ .boolean = true });
                            i += 1;
                            continue;
                        }
                        // for options e.g --hey hi
                        if (validArg.type == ArgumentType.option and i < args.len - 1) {
                            try self.destinations.put(validKey, .{ .string = args[i + 1] });
                            i += 2;
                            continue;
                        } else {
                            try std.io.getStdErr().writer().print("Invalid option with no argument {s}", .{currArg});
                            return ArgParserError.InValidOption;
                        }
                    }
                } else {
                    // positional arguments
                    const arg = self.arguments.get(.{ .number = positionalArg });
                    if (arg) |validArg| {
                        const validKey = if (validArg.dest.len == 0) currArg else validArg.dest;
                        try self.destinations.put(validKey, .{ .string = currArg });
                    }
                    positionalArg += 1;
                }

                i += 1;
            }

            return;
        }

        // private function to convert Argument to ArgumentInternal
        fn createArg(
            _: *Self,
            name: []const u8,
            argType: ArgumentType,
            help: []const u8,
            dest: []const u8,
            default: ArgumentDefault,
            required: bool,
        ) ArgumentInternal {
            return ArgumentInternal{
                .name = name,
                .type = argType,
                .help = help,
                .dest = dest,
                .default = default,
                .required = required,
            };
        }
        pub fn addArg(self: *Self, arg: Argument) !void {
            var argName = arg.name;
            var argType: ArgumentType = if (argName.len > 2 and std.mem.eql(u8, argName[0..2], &[2]u8{ self.prefixChar, self.prefixChar })) ArgumentType.option else ArgumentType.positional;
            argType = if (argType == ArgumentType.option and arg.isFlag) ArgumentType.flag else argType;
            const argVal: ArgumentInternal = self.createArg(argName, argType, arg.help, arg.dest, arg.default, arg.required);

            const argKey: ArgumentKey = switch (argType) {
                ArgumentType.positional => blk: {
                    const key = ArgumentKey{ .number = self.positionalArgSize };
                    self.positionalArgSize += 1;
                    break :blk key;
                },
                ArgumentType.option, ArgumentType.flag => ArgumentKey{ .string = argName },
            };
            try self.arguments.put(argKey, argVal);
        }
        pub fn getSize(self: *const Self) usize {
            return self.arguments.count();
        }

        pub fn getParsedArgs(self: *Self, key: []const u8) ?ArgumentValue {
            return self.destinations.get(key);
        }

        pub fn deinit(self: *Self) void {
            self.destinations.clearAndFree();
            self.arguments.clearAndFree();
            self.arguments.deinit();
            self.destinations.deinit();
        }
    };
}

test "Test if init and denit of argparser works" {
    var argparser = ArgParser().init(std.testing.allocator, .{});
    defer argparser.deinit();
}

test "Test that the argparser size increases by one when adding an argument" {
    var argparser = ArgParser().init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    try std.testing.expectEqual(1, argparser.getSize());
}

test "Test that the argparser does not return an error after parsing" {
    var argparser = ArgParser().init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    const argument = [_][]const u8{ "--hello", "bye2" };
    try argparser.parseArgs(argument[0..]);
}

test "Test that the argparser returns the right destination (if dest field not provided)" {
    var argparser = ArgParser().init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false});
    const argument = [_][]const u8{ "--hello", "bye3" };
    try argparser.parseArgs(&argument);
    const val = argparser.getParsedArgs("--hello") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "bye3" }, val);
}

test "Test that the argparser returns the right destination" {
    var argparser = ArgParser().init(std.testing.allocator, .{});
    defer argparser.deinit();
    try argparser.addArg(.{ .name = "--hello", .default = .{ .string = "bye" }, .required = false, .dest = "hello" });
    const argument = [_][]const u8{ "--hello", "bye3" };
    try argparser.parseArgs(&argument);
    const val = argparser.getParsedArgs("hello") orelse ArgumentValue{ .string = "" };
    try std.testing.expectEqual(ArgumentValue{ .string = "bye3" }, val);
}

