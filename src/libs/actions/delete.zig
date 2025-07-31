const std = @import("std");
const arg = @import("../utils/arg.zig");
const config = @import("../utils/config.zig");
const payload = @import("../utils/payload.zig");

const DeleteErrors = error{ NoValidTrashedEntityGiven, InvalidDeleteFileOrFolder, ErrorParsingArguments, UnexpectedError, NoArgumentSpecified };

pub const DeleteActionName = "delete";

const DeleteArg = arg.Argument{
    .name = "trashedEntity", // trashed entity could be a file, folder or a symbolic link in the dunk trash bin
    .dest = "trashedEntity",
    .required = true,
    .help = "This is the file/folder you want to permanently delete in the trash bin",
};

pub const DeleteAction = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    filesOrFoldersToPermDelete: []const []const u8,
    dunkConfig: config.DunkConfig,

    pub fn run(args: []const []const u8, allocator: std.mem.Allocator, dunkConfigPayload: *payload.ErrPayload(config.DunkConfig)) DeleteErrors!void {
        if (args.len == 0) {
            return DeleteErrors.NoArgumentSpecified;
        }
        var deleteArgParser = arg.ArgParser().init(allocator, .{ .programName = "Dunk Delete action" });
        defer deleteArgParser.deinit();
        deleteArgParser.addArg(DeleteArg) catch {
            dunkConfigPayload.format("Error occured while adding delete argument", .{});
            return DeleteErrors.ErrorParsingArguments;
        };
        deleteArgParser.parseArgs(args) catch {
            dunkConfigPayload.format("Error occured while parsing delete argument", .{});
            return DeleteErrors.ErrorParsingArguments;
        };
        const trashedEntity = deleteArgParser.getParsedArgs(DeleteArg.dest) orelse {
            dunkConfigPayload.format("Error occured while getting delete argument", .{});
            return DeleteErrors.NoValidTrashedEntityGiven;
        };

        var errPayload = payload.ErrPayload(void).init(.{ .allocator = allocator });

        switch (trashedEntity) {
            .boolean => unreachable,
            .string => |trashedEntityStr| {
                const arguments = [_][]const u8{trashedEntityStr};
                var deleteAct = Self.init(allocator, &arguments, dunkConfigPayload.payload);
                defer deleteAct.deinit();
                deleteAct.action(&errPayload) catch {
                    dunkConfigPayload.setMsg(errPayload.getErrMsg());
                };
            },
        }
    }

    pub fn init(
        allocator: std.mem.Allocator,
        filesOrFolderToPermDelete: []const []const u8,
        dunkConfig: config.DunkConfig,
    ) Self {
        return Self{ .allocator = allocator, .filesOrFoldersToPermDelete = filesOrFolderToPermDelete, .dunkConfig = dunkConfig };
    }
    pub fn deinit(_: *Self) void {}

    pub fn action(self: *Self, errPayload: *payload.ErrPayload(void)) DeleteErrors!void {

        // Go through all trashed files and delete
        for (self.filesOrFoldersToPermDelete) |filePath| {
            if (filePath.len == 0) {
                continue;
            }
            const absoluteFilePath = std.mem.concat(self.allocator, u8, &[_][]const u8{ self.dunkConfig.trashPath, filePath }) catch {
                errPayload.format("An Unexpected occured while concatenating file paths {s} and {s}", .{ self.dunkConfig.trashPath, filePath });
                return DeleteErrors.UnexpectedError;
            };
            defer self.allocator.free(absoluteFilePath);
            const file = std.fs.openFileAbsolute(absoluteFilePath, .{}) catch |err| switch (err) {
                std.fs.File.OpenError.FileNotFound => {
                    errPayload.format("File/Folder does not exist {s}. Cannot permanently delete from trash bin", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
                else => {
                    errPayload.format("Something went wrong while trying to permanently delete {s}", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
            };
            defer file.close();
        }
    }
};

test "test that delete action does not crash" {
    var errPayload = payload.ErrPayload(config.DunkConfig).init(.{ .allocator = std.testing.allocator });
    try DeleteAction.run(&[_][]const u8{""}, std.testing.allocator, &errPayload);
    try std.testing.expectEqual(undefined, errPayload.getErrMsg());
}
