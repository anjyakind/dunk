const arg = @import("../utils/arg.zig");


pub const DeleteArg = arg.Argument{
    .name = "--delete",
    .help = "For deleting files/directories from your trash bin permanently",
    .dest = "delete",
    .required = true,
};
