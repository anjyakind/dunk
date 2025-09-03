//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const actions = @import("actions");
const projectInfo = @import("projectInfo");
const utils = @import("utils");
const appargs = @import("args").appargs;
const config = utils.config;
const payload = utils.payload;

extern fn addSum(a: i64, b: i64) i64;

const usage =
    \\Dunk - Trash bin manager made in zig
    \\dunk [options|command] (command ?? [command-options])
    \\
    \\Options:
    \\  --help                    Print this help and exit
    \\  --version                 Print version number and exit
    \\
    \\Commands:
    \\  delete                    Permanently delete file/folder from trash
    \\  trash                     Move file/folder to the trash bin
    \\  restore                   Move trashed file/folder back to its original location
    \\  wipe                      Permanently delete all files and folders in the trash bin
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        _ = gpa.deinit();
    }

    const allocator = gpa.allocator();
    const cmdArgs = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, cmdArgs);

    var argParser = try appargs.DunkArgs.init(allocator);
    defer argParser.deinit();

    try argParser.parseArgs(cmdArgs);

    if (processHelpArg(&argParser, usage) or processVersionArg(&argParser)) {
        return;
    }

    const action = argParser.getActionSubcommand();
    const dunkConfig = config.DunkConfig{};

    var errPayload = payload.ErrPayload(void).init(.{ .allocator = allocator });
    defer errPayload.deinit();

    if (action) |validAction| {
        var subcommandParser = argParser.getActionSubArgParser(validAction) orelse unreachable;
        try subcommandParser.parseArgs(cmdArgs[2..]);
        switch (validAction) {
            .delete => {
                const argVal = subcommandParser.getParsedArgs(appargs.DunkArgs.fileOrFolderArg.name) orelse unreachable;
                switch (argVal) {
                    .strings => |ff_to_delete| {
                        actions.delete.DeleteAction.run(.{
                            .ff_to_delete = ff_to_delete,
                            .allocator = allocator,
                            .payload = &errPayload,
                            .config = dunkConfig,
                        }) catch {
                            std.log.err("{s}", .{errPayload.getErrMsg()});
                            return;
                        };
                    },
                    else => unreachable,
                }
            },
            .restore => {
                const argVal = subcommandParser.getParsedArgs(appargs.DunkArgs.fileOrFolderArg.name) orelse unreachable;
                switch (argVal) {
                    .strings => |ff_to_restore| {
                        actions.restore.RestoreAction.run(.{
                            .ff_to_restore = ff_to_restore,
                            .allocator = allocator,
                            .payload = &errPayload,
                            .config = dunkConfig,
                        }) catch {
                            std.log.err("{s}", .{errPayload.getErrMsg()});
                        };
                    },
                    else => unreachable,
                }
            },
            // TODO: Add all other actions e.g trash, wipe
            else => return,
        }
    } else {
        try unexpectedCommandUsageWarning(allocator);
    }
}

/// Warn User about incorrect usage of main dunk command
fn unexpectedCommandUsageWarning(allocator: std.mem.Allocator) !void {
    const arguments = [_][]const u8{
        actions.delete.DeleteActionName,
        actions.restore.RestoreActionName,
        actions.trash.TrashActionName,
        appargs.DunkArgs.helpFlag.name,
        appargs.DunkArgs.versionFlag.name,
    };
    var argumentList = std.ArrayList(u8).init(allocator);
    defer argumentList.deinit();

    for (arguments, 1..) |argument, i| {
        try std.fmt.format(argumentList.writer(), "{}. {s}\n", .{ i, argument });
    }
    std.log.warn(
        \\dunk [command|option] [arg-options]
        \\Positional argument or option is required. Please choose from the following:
        \\{s}
    ,
        .{argumentList.items},
    );
}

/// Helper function to handle finding --help flag
/// If it returns true that means it found the flag in the args
pub fn processHelpArg(argParser: *appargs.DunkArgs, helpUsage: []const u8) bool {
    const help = argParser.parser.getParsedArgs(appargs.DunkArgs.helpFlag.dest);
    if (help) |validHelp| {
        switch (validHelp) {
            .boolean => |helpVal| {
                if (helpVal == true) {
                    std.log.info("{s}", .{helpUsage});
                    return true;
                }
            },
            else => {
                return false;
            },
        }
    }
    return false;
}

/// Helper to handle finding the --version flag.
/// If it returns true than that means it found the flag in the args
pub fn processVersionArg(argParser: *appargs.DunkArgs) bool {
    const version = argParser.parser.getParsedArgs(appargs.DunkArgs.versionFlag.dest);
    if (version) |validVersion| {
        switch (validVersion) {
            .boolean => |versionVal| {
                if (versionVal == true) {
                    std.log.info("{any}", .{projectInfo.version});
                    return true;
                }
            },
            else => {
                return false;
            },
        }
    }
    return false;
}
