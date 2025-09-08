const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const wipe_test = @import("restore_test.zig");

const WipeErrors = error{};

pub const WipeActionName = "wipe";

pub const WipeActionConfig = struct {
    // files and folders to wipe
    ff_to_wipe: []const []const u8,
    config: config.DunkConfig,
    payload: *payload.ErrPayload(void),
    allocator: std.mem.Allocator,
};

pub const WipeAction = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    ff_to_wipe: []const []const u8,
    dunk_config: config.DunkConfig,

    /// Performs
    pub fn run(params: WipeActionConfig) WipeErrors!void {
        var errPayload = payload.ErrPayload(void).init(.{ .allocator = params.allocator });
        defer errPayload.deinit();

        var wipe_action = Self.init(params.allocator, params.ff_to_wipe, params.config);
        defer wipe_action.deinit();
        wipe_action.action(&errPayload) catch {
            params.payload.format("wipe run error: {s}", .{errPayload.getErrMsg()});
        };
    }

    /// Initializes WipeAction struct
    fn init(
        allocator: std.mem.Allocator,
        ff_to_wipe: []const []const u8,
        dunkConfig: config.DunkConfig,
    ) Self {
        return Self{
            .allocator = allocator,
            .ff_to_wipe = ff_to_wipe,
            .dunk_config = dunkConfig,
        };
    }

    /// De-Initializes WipeAction struct
    fn deinit(_: *Self) void {}

    fn action(_: *Self, _: *payload.ErrPayload(void)) WipeErrors!void {}
};

test {
    _ = wipe_test;
}
