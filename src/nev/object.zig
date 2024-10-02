const C = @import("c.zig");
const std = @import("std");

pub const Object = struct {
    ptr: [*c]C._nev.object,

    pub fn from_ptr(ptr: [*c]C._nev.object) Object {
        return Object{ .ptr = ptr };
    }

    pub fn new_int(i: i64) Object {
        return Object{ .ptr = C._nev.object_new_int(@intCast(i)) };
    }

    pub fn new_arr(size: usize) Object {
        const dim = C._nev.object_arr_dim_new(@intCast(size));
        const arr = C._nev.object_new_arr(@intCast(size), dim);
        return Object{ .ptr = arr };
    }

    pub fn new_str(str: []u8) !Object {
        return Object{ .ptr = C._nev.object_new_string(C.stringToCString(std.heap.c_allocator, str)) };
    }

    pub fn copy_arr(arr: Object) Object {
        return Object{ .ptr = C._nev.object_arr_copy(arr.ptr) };
    }

    pub fn new() !Object {
        return Object{ .ptr = try std.heap.c_allocator.create(C._nev.object) };
    }
};
