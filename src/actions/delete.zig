const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const delete_test = @import("delete_test.zig");

const DeleteErrors = error{ NoValidTrashedEntityGiven, InvalidDeleteFileOrFolder, ErrorParsingArguments, UnexpectedError, NoArgumentSpecified };

pub const DeleteActionName = "delete";

const DeleteActionConfig = struct {
    // files and folders to delete
    ff_to_delete: []const []const u8,
    allocator: std.mem.Allocator,
    config: config.DunkConfig,
    payload: *payload.ErrPayload(void),
};

pub const DeleteAction = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    ff_to_delete: []const []const u8,
    dunkConfig: config.DunkConfig,
    pub fn run(params: DeleteActionConfig) DeleteErrors!void {
        var errPayload = payload.ErrPayload(void).init(.{ .allocator = params.allocator });
        defer errPayload.deinit();

        var deleteAct = Self.init(params.allocator, params.ff_to_delete, params.config);
        defer deleteAct.deinit();
        deleteAct.action(&errPayload) catch {
            params.payload.format("Delete run error: {s}", .{errPayload.getErrMsg()});
        };
    }

    fn init(
        allocator: std.mem.Allocator,
        ff_to_delete: []const []const u8, // files and folders to delete
        dunkConfig: config.DunkConfig,
    ) Self {
        return Self{
            .allocator = allocator,
            .ff_to_delete = ff_to_delete,
            .dunkConfig = dunkConfig,
        };
    }
    fn deinit(_: *Self) void {}

    fn action(self: *Self, errPayload: *payload.ErrPayload(void)) DeleteErrors!void {

        // Go through all trashed files and delete
        for (self.ff_to_delete) |filePath| {
            if (filePath.len == 0) {
                continue;
            }
            const absoluteFilePath = std.mem.concat(self.allocator, u8, &[_][]const u8{ self.dunkConfig.trashPath, filePath }) catch {
                errPayload.format("An Unexpected occured while concatenating file paths {s} and {s}", .{ self.dunkConfig.trashPath, filePath });
                return DeleteErrors.UnexpectedError;
            };
            defer self.allocator.free(absoluteFilePath);
            std.fs.accessAbsolute(absoluteFilePath, .{ .mode = .read_write }) catch |err| switch (err) {
                std.fs.Dir.AccessError.PermissionDenied => {
                    errPayload.format("You do not have permissions to delete File/Folder {s}. Cannot permanently delete from trash bin", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
                std.fs.Dir.AccessError.FileNotFound => {
                    errPayload.format("File/Folder {s} does not exist. Cannot permanently delete from trash bin", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
                else => {
                    errPayload.format("Something went wrong while trying to permanently delete {s}", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
            };

            std.fs.deleteFileAbsolute(filePath) catch |err| switch (err) {
                else => {
                    errPayload.format("Could not permanently delete {s} for some unknown reason.", .{filePath});
                    return DeleteErrors.InvalidDeleteFileOrFolder;
                },
            };
        }
    }
};

test {
    _ = delete_test;
}
