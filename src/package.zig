const std = @import("std");

pub const ExecutionPackage = struct {
    pub const Configuration = struct {
        functions: []struct {
            name: []const u8,
            execution: []const u8,
            parameters: [][]const u8,

            result: []const u8,
        },
        path: ?[]const u8,
        code: ?[]const u8,
    };

    pub fn load(package: []u8) !Configuration {
        const decompressed_package = ExecutionPackage.decompress(package);
        const json = try std.json.parseFromSlice(Configuration, std.heap.page_allocator, decompressed_package, .{});
        return json.value;
    }

    pub fn build(package: []u8) []u8 {
        return ExecutionPackage.compress(package);
    }

    /// Compresses the input using Run-Length Encoding (RLE)
    fn compress(input: []const u8) []u8 {
        var result: []u8 = undefined;
        var writer = std.ArrayList(u8).init(std.heap.page_allocator);

        if (input.len == 0) return result; // If the input is empty, return an empty result

        var count: u8 = 1;
        var prev_char: u8 = input[0];

        for (input[1..]) |c| {
            if (c == prev_char and count < 255) {
                count += 1;
            } else {
                writer.append(prev_char) catch return result;
                writer.append(count) catch return result;
                prev_char = c;
                count = 1;
            }
        }

        // Append the last run
        writer.append(prev_char) catch return result;
        writer.append(count) catch return result;

        // Copy to a result buffer and return
        result = writer.toOwnedSlice() catch return result;
        return result;
    }

    /// Decompresses the compressed input back into the original string
    fn decompress(input: []const u8) []u8 {
        var result: []u8 = undefined;
        var writer = std.ArrayList(u8).init(std.heap.page_allocator);

        if (input.len % 2 != 0) return result; // Invalid RLE data if length is odd

        var i: usize = 0;
        while (i < input.len) {
            const char = input[i];
            const count = input[i + 1];

            // Repeat the character `count` times
            for (count) |_| {
                writer.append(char) catch return result;
            }

            i += 2;
        }

        // Copy to a result buffer and return
        result = writer.toOwnedSlice() catch return result;
        return result;
    }
};
