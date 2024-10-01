const std = @import("std");

pub fn parseLines(allocator: std.mem.Allocator, content: []const u8) ![][]u8 {
    var iter = std.mem.splitSequence(u8, content, "\n");
    var instructions = std.ArrayList([]u8).init(allocator);

    while (iter.next()) |val| {
        const trimmed = std.mem.trim(u8, val, " \t");

        if (trimmed.len > 0) {
            try instructions.append(@constCast(trimmed));
        }
    }

    return instructions.items;
}
