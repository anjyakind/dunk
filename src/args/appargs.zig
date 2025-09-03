const std = @import("std");
const argparser = @import("argparser.zig");
/// subcommand argument. Look at usage for more information
const subcommandArg = argparser.Argument{
    .name = "subcommand",
    .dest = "subcommand",
    .help = "subcommand to be performed e.g wipe, remove, restore, delete",
    .required = true,
};

pub const DunkArgs = struct {
    pub const ActionSubcommand = enum { delete, remove, wipe, restore };
    /// Argument for handling version flag
    pub const versionFlag = argparser.Argument{
        .name = "--version",
        .dest = "version",
        .help = "Print version of tool",
        .required = false,
        .isFlag = true,
    };

    /// Argument for handling help flag
    pub const helpFlag = argparser.Argument{
        .name = "--help",
        .dest = "help",
        .help = "Print for help",
        .required = false,
        .isFlag = true,
    };

    pub const fileOrFolderArg = argparser.Argument{
        .name = "filesOrFolders",
        .help = "Files and folders to be permanently deleted in the trash",
        .nargs = .infinite,
    };

    const Self = @This();

    /// root argument parser for handling entire app argument parsing
    parser: argparser.ArgParser(.{ .enumType = ActionSubcommand }),

    /// Initialization function pa
    pub fn init(allocator: std.mem.Allocator) !Self {
        var dunkArg = Self{ .parser = .init(allocator, .{ .programName = "Dunk" }) };

        try dunkArg.parser.addArg(versionFlag);
        try dunkArg.parser.addArg(helpFlag);
        try dunkArg.parser.createSubcommandParser(
            ActionSubcommand.delete,
            .void,
            .{ .programName = "Dunk delete action" },
            setupSubcommandArgParsers,
        );
        try dunkArg.parser.createSubcommandParser(
            ActionSubcommand.wipe,
            .void,
            .{ .programName = "Dunk wipe action" },
            setupSubcommandArgParsers,
        );

        try dunkArg.parser.createSubcommandParser(
            ActionSubcommand.remove,
            .void,
            .{ .programName = "Dunk remove action" },
            setupSubcommandArgParsers,
        );
        try dunkArg.parser.createSubcommandParser(
            ActionSubcommand.restore,
            .void,
            .{ .programName = "Dunk restore action" },
            setupSubcommandArgParsers,
        );

        return dunkArg;
    }

    pub fn deinit(self: *Self) void {
        self.parser.deinit();
    }

    pub fn setupSubcommandArgParsers(parser: *argparser.ArgParser(.void)) !void {
        try parser.addArg(helpFlag);
        try parser.addArg(fileOrFolderArg);
    }

    /// Wrapper function to call internal parser's parseArgs function
    pub fn parseArgs(self: *Self, args: []const []const u8) !void {
        return self.parser.parseArgs(args);
    }

    /// Gets detected action subcommand after parsing arguments. Wrapper
    /// for internal parser's getSubcommand function.
    pub fn getActionSubcommand(self: *Self) ?ActionSubcommand {
        return self.parser.getSubcommand();
    }

    pub fn getActionSubArgParser(self: *Self, subcommand: ActionSubcommand) ?argparser.IArgParser {
        return self.parser.getSubcommandParser(subcommand);
    }
};
