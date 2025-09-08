const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const WipeAction = @import("wipe.zig").WipeAction;

test "test that wipe action does not crash" {
    var errPayload = payload.ErrPayload(void).init(.{
        .allocator = std.testing.allocator,
    });

    try WipeAction.run(.{
        .ff_to_trash = &[_][]const u8{""},
        .allocator = std.testing.allocator,
        .payload = &errPayload,
        .config = config.DunkConfig{},
    });

    try std.testing.expectEqual("", errPayload.getErrMsg());
}
