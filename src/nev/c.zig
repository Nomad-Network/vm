const std = @import("std");

pub const _nev = @cImport(@cInclude("nev.h"));

pub fn stringToCString(allocator: std.mem.Allocator, str: []u8) ![:0]u8 {
    const n = try allocator.allocSentinel(u8, str.len + 1, 0);
    std.mem.copyForwards(u8, n, str);
    n[n.len - 1] = 0;

    return n;
}
