const std = @import("std");

const ErrorPayloadErr = error{GettingANullMsg};

pub fn ErrPayload(comptime T: type) type {
    return struct {
        payload: T = T{},
        errMsg: ?[]const u8 = null,
        allocator: std.mem.Allocator,
        const Self = @This();

        pub fn init(args: struct { allocator: std.mem.Allocator, payload: T = T{} }) Self {
            return Self{ .allocator = args.allocator, .payload = args.payload };
        }

        pub fn deinit(self: *Self) void {
            if (self.errMsg) |errMsg| {
                self.allocator.free(errMsg);
                self.errMsg = null;
            }
        }

        pub fn format(self: *Self, comptime string: []const u8, args: anytype) void {
            self.errMsg = std.fmt.allocPrint(self.allocator, string, args) catch blk: {
                std.log.err("An error occured while formatting this string: {s}", .{string});
                break :blk null;
            };
        }

        pub fn setMsg(self: *Self, string: []const u8) void {
            self.errMsg = self.allocator.dupe(u8, string) catch blk: {
                std.log.err("An error occured while setting errMsg: {s}", .{string});
                break :blk null;
            };
        }

        pub fn getErrMsg(self: *Self) []const u8 {
            if (self.errMsg) |errMsg| {
                return errMsg;
            }
            return "";
        }
    };
}
