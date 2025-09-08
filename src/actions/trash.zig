const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const trash_test = @import("trash_test.zig");

const TrashErrors = error{};

pub const TrashActionName = "trash";

pub const TrashActionConfig = struct {
    // files and folders to trash
    ff_to_trash: []const []const u8,
    config: config.DunkConfig,
    payload: *payload.ErrPayload(void),
    allocator: std.mem.Allocator,
};

pub const TrashAction = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    ff_to_trash: []const []const u8,
    dunk_config: config.DunkConfig,

    pub fn run(params: TrashActionConfig) TrashErrors!void {
        var errPayload = payload.ErrPayload(void).init(.{ .allocator = params.allocator });
        defer errPayload.deinit();

        var trash_action = Self.init(params.allocator, params.ff_to_trash, params.config);
        defer trash_action.deinit();
        trash_action.action(&errPayload) catch {
            params.payload.format("trash run error: {s}", .{errPayload.getErrMsg()});
        };
    }

    fn init(
        allocator: std.mem.Allocator,
        ff_to_trash: []const []const u8,
        dunkConfig: config.DunkConfig,
    ) Self {
        return Self{
            .allocator = allocator,
            .ff_to_trash = ff_to_trash,
            .dunk_config = dunkConfig,
        };
    }
    fn deinit(_: *Self) void {}

    fn action(_: *Self, _: *payload.ErrPayload(void)) TrashErrors!void {}
};

test {
    _ = trash_test;
}
