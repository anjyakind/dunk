const std = @import("std");
const utils = @import("utils");
const config = utils.config;
const payload = utils.payload;
const DeleteAction = @import("delete.zig").DeleteAction;

test "test that delete action does not crash" {
    var errPayload = payload.ErrPayload(config.DunkConfig).init(.{ .allocator = std.testing.allocator });
    try DeleteAction.run(&[_][]const u8{""}, std.testing.allocator, &errPayload);
    try std.testing.expectEqual("", errPayload.getErrMsg());
}
