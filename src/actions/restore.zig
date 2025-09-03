const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;

const RestoreErrors = error{};

pub const RestoreActionName = "delete";

pub const RestoreActionConfig = struct {
    // files and folders to restore
    ff_to_restore: []const []const u8,
    config: config.DunkConfig,
    payload: *payload.ErrPayload(void),
    allocator: std.mem.Allocator,
};

pub const RestoreAction = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    ff_to_restore: []const []const u8,
    dunkConfig: config.DunkConfig,

    pub fn run(params: RestoreActionConfig) RestoreErrors!void {
        var errPayload = payload.ErrPayload(void).init(.{ .allocator = params.allocator });
        defer errPayload.deinit();

        var restoreAct = Self.init(params.allocator, params.ff_to_restore, params.config);
        defer restoreAct.deinit();
        restoreAct.action(&errPayload) catch {
            params.payload.format("Restore run error: {s}", .{errPayload.getErrMsg()});
        };
    }

    fn init(
        allocator: std.mem.Allocator,
        ff_to_restore: []const []const u8,
        dunkConfig: config.DunkConfig,
    ) Self {
        return Self{
            .allocator = allocator,
            .ff_to_restore = ff_to_restore,
            .dunkConfig = dunkConfig,
        };
    }
    fn deinit(_: *Self) void {}

    fn action(_: *Self, _: *payload.ErrPayload(void)) RestoreErrors!void {}
};
