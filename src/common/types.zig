const std = @import("std");

pub const Primitives = enum(u8) {
    u64,
    u32,
    u16,
    u8,
    u4,
    u2,
    u1,

    i64,
    i32,
    i16,
    i8,
    i4,
    i2,
    i1,

    pub fn bitSize(self: @This()) u64 {
        return switch (self) {
            .u64 => 64,
            .u32 => 32,
            .u16 => 16,
            .u8,
            => 8,
            .u4,
            => 4,
            .u2,
            => 2,
            .u1,
            => 1,

            .i64 => 64,
            .i32 => 32,
            .i16 => 16,
            .i8,
            => 8,
            .i4,
            => 4,
            .i2,
            => 2,
            .i1,
            => 1,
        };
    }
};
