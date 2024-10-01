const clap = @import("clap");
const std = @import("std");
const lib = @import("root.zig");
const file_utils = @import("./utils/file.zig");
const common_memory = @import("./common/memory.zig");
const compiler_commands = @import("./compiler/commands.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help         Display this help and exit.
        \\-v, --version      Output version information and exit.
        \\-o, --output <str> Output path of the Nomad Data Query bytecode
        \\<str>...          
        \\
    );

    var res = try clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = allocator,
    });
    defer res.deinit();

    const ndqCommands = try compiler_commands.loadCommands(allocator);

    var outputFile: []const u8 = "out.nqb";

    // `clap.usage` is a function that can print a simple help message. It can print any `Param`
    // where `Id` has a `value` method (`Param(Help)` is one such parameter).
    if (res.args.help != 0)
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
    if (res.args.version != 0)
        return std.log.info("version: {s}", .{"0.0.0"});
    if (res.args.output) |o| {
        outputFile = o;
    }

    if (std.mem.eql(u8, res.positionals[0], "execute")) return;

    for (res.positionals) |pos| {
        std.log.info("FILE: {s}", .{pos});
        var table = common_memory.ProgramTable.init(allocator, @constCast(pos));
        const content = try file_utils.readFile(allocator, pos);
        const split_sources = try lib.parseLines(allocator, content);

        for (split_sources) |sources| {
            const cmds = try common_memory.processCommand(allocator, sources);
            const cmd = ndqCommands.get(cmds[0]);

            if (cmd) |_fn| {
                try _fn(&table, cmds[1..]);
            }
            std.log.debug("{s}: {s}", .{ sources, cmds[0] });
        }

        std.log.debug("=> {s}", .{outputFile});

        if (table.findProcByName(@constCast("main"))) |mainProc| {
            std.log.debug("main: {any}", .{mainProc.id});
        }
    }
}
