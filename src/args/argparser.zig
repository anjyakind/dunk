const std = @import("std");
const argparser_test = @import("argparser_test.zig");

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
    default: ArgumentDefault = .{ .string = "" },
    required: bool = true,
    isFlag: bool = false,
    help: []const u8 = "",
    nargs: union(enum) { finite: usize, infinite } = .{ .finite = 1 },
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
    strings: []const []const u8,
};
const ArgumentParserConfig = struct {
    description: []const u8 = "",
    programName: []const u8 = "",
    exitOnErr: bool = true,
    prefixChar: u8 = '-',
    usage: []const u8 = "",
    noOfArgsToSkip: usize = 1,
};

const ArgParserError = error{
    InValidOption,
};

pub const IArgParser = struct {
    ptr: *anyopaque,
    vtable: struct {
        deinit: *const fn (ptr: *anyopaque) void,
        parseArgs: *const fn (ptr: *anyopaque, args: []const []const u8) anyerror!void,
        getParsedArgs: *const fn (ptr: *anyopaque, key: []const u8) ?ArgumentValue,
        destroy: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    },

    fn init(ptr: anytype) IArgParser {
        const T = @TypeOf(ptr);
        const ptrInfo = @typeInfo(T);

        const gen = struct {
            pub fn deinit(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptrInfo.pointer.child.deinit(self);
            }
            pub fn parseArgs(pointer: *anyopaque, args: []const []const u8) anyerror!void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptrInfo.pointer.child.parseArgs(self, args);
            }
            pub fn getParsedArgs(pointer: *anyopaque, key: []const u8) ?ArgumentValue {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptrInfo.pointer.child.getParsedArgs(self, key);
            }
            pub fn destroy(pointer: *anyopaque, allocator: std.mem.Allocator) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptrInfo.pointer.child.destroy(self, allocator);
            }
        };

        return .{ .ptr = ptr, .vtable = .{
            .deinit = gen.deinit,
            .parseArgs = gen.parseArgs,
            .getParsedArgs = gen.getParsedArgs,
            .destroy = gen.destroy,
        } };
    }

    pub fn deinit(self: *IArgParser) void {
        return self.vtable.deinit(self.ptr);
    }
    pub fn parseArgs(self: *IArgParser, args: []const []const u8) anyerror!void {
        return self.vtable.parseArgs(self.ptr, args);
    }
    pub fn getParsedArgs(self: *IArgParser, key: []const u8) ?ArgumentValue {
        return self.vtable.getParsedArgs(self.ptr, key);
    }
    pub fn destroy(self: *IArgParser, allocator: std.mem.Allocator) void {
        return self.vtable.destroy(self.ptr, allocator);
    }
};

/// Helps to make sure that the subcommand type is just an enum type.
/// Note: enum and enum literals are two different things
fn validateSubcommandType(comptime T: SubcommandType) void {
    switch (T) {
        .void => return,
        .enumType => |concEnumType| {
            switch (@typeInfo(concEnumType)) {
                std.builtin.Type.@"enum" => {
                    return;
                },
                else => {
                    @compileError("SubcommandType must be an enum but got " ++ @typeName(concEnumType));
                },
            }
        },
    }
}

test "make sure validateSubcommandType allows enum and null types only" {
    validateSubcommandType(.{ .enumType = enum {
        a,
        b,
        c,
    } });
    validateSubcommandType(.void);
}

pub const SubcommandType = union(enum) {
    void: void,
    enumType: type,
};

/// ArgParser type
pub fn ArgParser(comptime ST: SubcommandType) type {
    comptime validateSubcommandType(ST);
    const DetectedSubcommandType = comptime switch (ST) {
        .void => void,
        .enumType => |actualEnumType| blk: {
            break :blk actualEnumType;
        },
    };
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        arguments: std.HashMap(ArgumentKey, ArgumentInternal, ArgumentKeyContext, std.hash_map.default_max_load_percentage),
        config: ArgumentParserConfig,
        destinations: std.StringHashMap(ArgumentValue),
        positionalArgSize: u32 = 0,
        detectedSubcommand: ?DetectedSubcommandType = null,
        mapSubparsers: std.AutoHashMap(DetectedSubcommandType, IArgParser),

        /// returns an ArgParser initialized on the stack with your config
        pub fn init(allocator: std.mem.Allocator, config: ArgumentParserConfig) Self {
            const parser = Self{
                .allocator = allocator,
                .arguments = .init(allocator),
                .destinations = .init(allocator),
                .config = config,
                .mapSubparsers = .init(allocator),
            };

            return parser;
        }

        /// returns an ArgParser initialized on the heap with your config
        pub fn create(allocator: std.mem.Allocator, config: ArgumentParserConfig) !*Self {
            const parser = try allocator.create(ArgParser(ST));
            parser.* = init(allocator, config);

            return parser;
        }

        /// destroy heap initialized ArgParser
        pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
            self.deinit();
            allocator.destroy(self);
        }

        /// Returns the detected subcommand enum found after invoking parseArgs.
        /// If SubcommandType.void was given then this function will return null.
        /// If no command was detected then null will also be returned.
        pub fn getSubcommand(self: *Self) ?DetectedSubcommandType {
            return self.detectedSubcommand;
        }

        /// Returns the subcommand parser assigned to the subcommand enum given.
        /// If no subcommand parser was created for the subcommand enum in question, then
        /// null will be returned
        pub fn getSubcommandParser(self: *Self, command: DetectedSubcommandType) ?IArgParser {
            return self.mapSubparsers.get(command);
        }

        /// Convert to IArgParser interface
        pub fn toIArgParser(self: *Self) IArgParser {
            return IArgParser.init(self);
        }

        /// Creates a Subcommand ArgParser for the selected subcommand enum. An optional setup
        /// callback can be used to setup Subcommand ArgParser after allocation. The parent ArgParser will be
        /// in charge of its lifetime.
        pub fn createSubcommandParser(
            self: *Self,
            command: DetectedSubcommandType,
            comptime subcommandType: SubcommandType,
            config: ArgumentParserConfig,
            setup: ?fn (*ArgParser(subcommandType)) anyerror!void,
        ) !void {
            const newSubcommandParser = try ArgParser(subcommandType).create(self.allocator, config);
            if (setup) |validSetup| {
                try validSetup(newSubcommandParser);
            }
            try self.mapSubparsers.put(command, newSubcommandParser.toIArgParser());
        }

        /// Checks if string matches any field from the Subcommand enum
        /// for subcommand in SubcommandType enum. If this method returns true
        /// then the self
        pub fn findSubcommand(self: *Self, str: []const u8) bool {
            return switch (ST) {
                .void => false,
                .enumType => |concEnumType| blk: {
                    inline for (@typeInfo(concEnumType).@"enum".fields) |enumField| {
                        if (std.mem.eql(u8, str, enumField.name)) {
                            self.detectedSubcommand = @enumFromInt(enumField.value);
                            break :blk true;
                        }
                    }
                    break :blk false;
                },
            };
        }

        /// parses arguments and initializes destinations so that values
        /// could be returned
        pub fn parseArgs(self: *Self, args: []const []const u8) !void {
            self.destinations.clearRetainingCapacity();
            var positionalArg: u8 = 0;
            var i: usize = self.config.noOfArgsToSkip;

            if (args.len >= 2 and i < args.len and self.findSubcommand(args[i])) {
                return;
            }
            while (i < args.len) {
                const currArg = args[i];
                // long form options
                if (currArg.len > 2 and std.mem.eql(u8, currArg[0..2], &[2]u8{ self.config.prefixChar, self.config.prefixChar })) {
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
                        const validKey = if (validArg.dest.len == 0) validArg.name else validArg.dest;
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
            var argType: ArgumentType = if (argName.len > 2 and std.mem.eql(u8, argName[0..2], &[2]u8{
                self.config.prefixChar,
                self.config.prefixChar,
            })) ArgumentType.option else ArgumentType.positional;
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

            var mapIt = self.mapSubparsers.iterator();

            while (mapIt.next()) |entry| {
                entry.value_ptr.destroy(self.allocator);
            }

            self.mapSubparsers.deinit();
        }
    };
}

test {
    _ = argparser_test;
}
