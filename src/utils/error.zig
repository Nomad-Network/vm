const std = @import("std");

pub const ResultError = error{UnhandledError};

pub const Severity = enum {
    fatal,
    warn,
    inconvenience,
};

pub fn Result(comptime T: type) T {
    return union(enum) {
        const Self = @This();

        ok: T,
        err: Error,

        pub fn unwrap(self: Self) !T {
            switch (self) {
                .ok => |ok| return ok,
                .err => |err| {
                    std.log.err("{s} [{any}]: {s}", .{ err.code, err.severity, err.message });
                    return error.UnhandledError;
                },
            }
        }
    };
}

pub const Error = struct {
    code: []const u8,
    message: []const u8,
    severity: Severity,
};
