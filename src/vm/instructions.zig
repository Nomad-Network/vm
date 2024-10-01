const std = @import("std");
const common_memory = @import("../common/memory.zig");

pub const ProgramContext = struct {
    variables: std.StringHashMap(common_memory.MemoryAllocation),
    current_definition: []const u8,
    current_proc: []const u8,
};
