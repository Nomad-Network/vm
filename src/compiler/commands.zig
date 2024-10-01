const std = @import("std");
const common = @import("../common/memory.zig");
const mem_utils = @import("../utils/mem.zig");

const CommandError = error{ IntParse, AllocError, NDQAllocError, SyntaxError };

pub const Command = *const fn (*common.ProgramTable, [][]u8) CommandError!void;

const CommandFunctions = struct {
    pub fn define(program: *common.ProgramTable, args: [][]u8) CommandError!void {
        std.debug.print("define INST({s}) PROG({s})\n", .{ args, program.name });

        const allocator = program.getAllocator();

        var is_string = false;
        var string_value: []u8 = "";
        var integer_value: usize = 0;

        var name = allocator.alloc(u8, args[0].len) catch return CommandError.AllocError;
        const raw_value = allocator.alloc(u8, args[1].len) catch return CommandError.AllocError;

        std.mem.copyForwards(u8, name, args[0]);
        std.mem.copyForwards(u8, raw_value, args[1]);

        name = @constCast(std.mem.trimLeft(u8, name, " "));

        integer_value = std.fmt.parseInt(usize, args[1], 0) catch blk: {
            is_string = true;
            string_value = raw_value;

            break :blk 0;
        };

        var allocation = common.MemoryAllocation.init(name, 32, null);

        switch (is_string) {
            true => allocation.setValue(string_value),
            false => {
                const bytes = mem_utils.u64ToEightBytes(integer_value, .little);
                allocation.setValue(mem_utils.sizedArrayToSlice(u8, 8, program.getAllocator(), bytes) catch return CommandError.AllocError);
            },
        }

        program.addAllocation(allocation) catch return CommandError.NDQAllocError;
    }

    pub fn proc(program: *common.ProgramTable, args: [][]u8) CommandError!void {
        if (program.current_proc != null) return CommandError.SyntaxError;

        std.debug.print("proc INST({s}) PROG({s}) ", .{ args, program.name });

        const allocator = program.getAllocator();

        const name = @constCast(std.mem.trimLeft(u8, args[0], " "));

        const proc_table = common.ProcTable.init(allocator, name);
        program.current_proc = proc_table;

        program.addProcess(proc_table) catch return CommandError.AllocError;

        std.debug.print("PTR({s})\n", .{program.current_proc.?.name});

        for (args[1..]) |arg| {
            if (arg[0] == '.') {
                const attr = argToAttribute(allocator, arg[1..]) catch return CommandError.AllocError;
                program.current_proc.?.attributes.put(attr.name, attr) catch return CommandError.AllocError;
            }
        }
    }

    pub fn endproc(program: *common.ProgramTable, _: [][]u8) CommandError!void {
        if (program.current_proc == null) return CommandError.SyntaxError;

        std.debug.print("endproc PROC({s}) PROG({s})\n", .{ program.current_proc.?.name, program.name });

        program.current_proc = null;
    }
};

pub const Commands = std.StringHashMap(Command);

fn argToAttribute(allocator: std.mem.Allocator, attr: []u8) !common.ProcAttribute {
    if (std.mem.indexOf(u8, attr, "=") == null) return .{ .name = attr, .type = .{ .boolean = true } };

    var attr_iter = std.mem.split(u8, attr, "=");

    const name = attr_iter.next() orelse "";
    const value = attr_iter.next() orelse "";

    var is_string = false;
    var string_value: []u8 = "";

    const raw_value = allocator.alloc(u8, value.len) catch return CommandError.AllocError;
    std.mem.copyForwards(u8, raw_value, value);

    const integer_value = std.fmt.parseInt(usize, value, 0) catch blk: {
        is_string = true;
        string_value = raw_value;

        break :blk 0;
    };

    return if (is_string) .{ .name = @constCast(name), .type = .{ .string = string_value } } else .{ .name = @constCast(name), .type = .{ .number = integer_value } };
}

pub fn loadCommands(alloc: std.mem.Allocator) !Commands {
    var cmds = Commands.init(alloc);

    try cmds.put(".define", &CommandFunctions.define);
    try cmds.put("proc", &CommandFunctions.proc);
    try cmds.put("endproc", &CommandFunctions.endproc);

    return cmds;
}
