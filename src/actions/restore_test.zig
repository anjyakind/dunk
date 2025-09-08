const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const RestoreAction = @import("restore.zig").RestoreAction;

test "test that restore action does not crash" {
    var errPayload = payload.ErrPayload(void).init(.{ .allocator = std.testing.allocator });
    try RestoreAction.run(.{
        .ff_to_restore = &[_][]const u8{""},
        .allocator = std.testing.allocator,
        .payload = &errPayload,
        .config = config.DunkConfig{},
    });
    try std.testing.expectEqual("", errPayload.getErrMsg());
}
