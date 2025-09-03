pub const DunkConfig = struct {
    const Self = @This();
    trashPath: []const u8 = "~/.dunk/",
    configPath: []const u8 = "~/.config/.dunk/",
};
