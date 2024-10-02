//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const clap = @import("clap");
const Ymlz = @import("ymlz").Ymlz;
const nomadvm = @import("nomadvm");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-c, --config <str>     An option parameter, which takes a value.
        \\-o, --output <str>     Output of compiled bundle
        \\-e, --execute <str>    An option parameter which can be specified multiple times.
        \\-f, --function <str>   The package function to call.
        \\-a, --args <str>...    The arguments to pass to the function.   
        \\<str>...
        \\
    );

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    if (res.args.config) |config| {
        const config_content = try nomadvm.utils.readFile(std.heap.page_allocator, config);
        std.log.info("{s}", .{config_content});

        const result = try std.json.parseFromSlice(nomadvm.Package.Configuration, std.heap.page_allocator, config_content, .{});
        var package_config = result.value;

        if (res.args.output) |output| {
            if (package_config.path) |code_path| {
                const code_content = try nomadvm.utils.readFile(std.heap.page_allocator, code_path);

                package_config.code = code_content;
                package_config.path = null;
            }

            _ = nomadvm.utils.fileExists(output, .{ .create_if_not_exist = true });
            const parsed_package = try std.json.stringifyAlloc(std.heap.page_allocator, package_config, .{});
            const built_package = nomadvm.Package.build(parsed_package);
            try nomadvm.utils.writeFile(output, built_package);
        }
    } else if (res.args.execute) |_| {
        @panic("TODO: Implement package execution.");
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
