const std = @import("std");


pub const delete = @import("delete.zig");
pub const restore = @import("restore.zig");
pub const wipe = @import("wipe.zig");
pub const trash = @import("trash.zig");


test {
    _ = delete;
    _ = restore;
    _ = wipe;
    _ = trash;
}
