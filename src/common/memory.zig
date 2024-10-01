const std = @import("std");
const mem_utils = @import("../utils/mem.zig");

pub const VariableID = [4]u8;
pub const Instruction = [:0]u8;

pub const ProcAttributeType = union(enum) {
    boolean: bool,
    string: []u8,
    number: usize,
};

pub const ProcAttribute = struct {
    name: []u8,
    type: ProcAttributeType,
};

pub const ProcTable = struct {
    name_len: usize,
    name: []u8,

    instructions: std.ArrayList(Instruction),
    instruction_len: usize,

    attributes: std.StringHashMap(ProcAttribute),

    id: VariableID,

    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, name: []u8) ProcTable {
        var crc32 = std.hash.Crc32.init();
        crc32.update(name);

        const hash = crc32.final();

        return ProcTable{ .name_len = 0, .name = name, .instructions = std.ArrayList(Instruction).init(alloc), .instruction_len = 0, .attributes = std.StringHashMap(ProcAttribute).init(alloc), .id = mem_utils.u32ToFourBytes(hash, .little), .alloc = alloc };
    }

    pub fn addInstruction(self: *ProcTable, inst: Instruction) !void {
        return try self.instructions.append(inst);
    }

    pub fn deserialize(self: *ProcTable) ![]u8 {
        var alloc_bytes = std.ArrayList(u8).init(self.alloc);

        try alloc_bytes.appendSlice(self.id);
        try alloc_bytes.appendSlice(&mem_utils.u64ToEightBytes(self.instructions.items.len, .little));

        for (self.instructions.items) |inst| {
            try alloc_bytes.appendSlice(inst);
        }

        return alloc_bytes.items;
    }
};

pub const MemoryAllocation = struct {
    bit_size: usize,
    name: []u8,
    id: VariableID,
    value: ?[]u8,

    pub fn init(name: []u8, size: usize, value: ?[]u8) MemoryAllocation {
        var crc32 = std.hash.Crc32.init();
        crc32.update(name);

        const hash = crc32.final();

        return MemoryAllocation{ .name = name, .bit_size = if (value != null) size else 0, .id = mem_utils.u32ToFourBytes(hash, .little), .value = value };
    }

    pub fn setValue(self: *MemoryAllocation, value: []u8) void {
        self.value = value;
        self.bit_size = value.len * 8;
    }

    pub fn deserialize(self: MemoryAllocation, allocator: std.mem.Allocator) ![]u8 {
        var alloc_bytes = std.ArrayList(u8).init(allocator);

        try alloc_bytes.appendSlice(&self.id);
        try alloc_bytes.appendSlice(&mem_utils.u64ToEightBytes(self.name.len, .little));
        try alloc_bytes.appendSlice(self.name);
        try alloc_bytes.appendSlice(&mem_utils.u64ToEightBytes(self.bit_size, .little));

        if (self.value) |v| {
            try alloc_bytes.appendSlice(v);
        }

        return alloc_bytes.items;
    }
};

pub const ProgramTable = struct {
    name_len: usize,
    name: []u8,

    instruction_pointer: u64,

    alloc: std.mem.Allocator,
    current_proc: ?ProcTable = null,

    allocations_len: usize,
    allocations: std.ArrayList(MemoryAllocation),

    processes_len: usize,
    processes: std.ArrayList(ProcTable),

    instructions: std.ArrayList(Instruction),

    pub fn init(alloc: std.mem.Allocator, name: []u8) ProgramTable {
        return ProgramTable{
            .name_len = 0,
            .name = name,

            .instruction_pointer = 0,

            .alloc = alloc,

            .allocations_len = 0,
            .allocations = std.ArrayList(MemoryAllocation).init(alloc),

            .processes_len = 0,
            .processes = std.ArrayList(ProcTable).init(alloc),

            .instructions = std.ArrayList(Instruction).init(alloc),
        };
    }

    pub fn getAllocator(self: *ProgramTable) std.mem.Allocator {
        return self.alloc;
    }

    pub fn addAllocation(self: *ProgramTable, alloc: MemoryAllocation) !void {
        self.allocations_len += 1;
        return try self.allocations.append(alloc);
    }

    pub fn findAllocByName(self: *ProgramTable, name: []u8) ?MemoryAllocation {
        for (self.allocations.items) |alloc| {
            if (std.mem.eql(u8, alloc.name, name)) return alloc;
        }

        return null;
    }

    pub fn findAllocByID(self: *ProgramTable, id: VariableID) ?MemoryAllocation {
        for (self.allocations.items) |alloc| {
            if (std.mem.eql(u8, alloc.id, id)) return alloc;
        }

        return null;
    }

    pub fn addProcess(self: *ProgramTable, proc: ProcTable) !void {
        self.processes_len += 1;
        return try self.processes.append(proc);
    }

    pub fn findProcByName(self: *ProgramTable, name: []u8) ?ProcTable {
        for (self.processes.items) |proc| {
            std.log.debug("? {s} <=> {s}", .{ proc.name, name });
            if (std.mem.eql(u8, proc.name, name)) return proc;
        }

        return null;
    }

    pub fn findProcByID(self: *ProgramTable, id: VariableID) ?ProcTable {
        for (self.processes.items) |proc| {
            if (std.mem.eql(u8, proc.id, id)) return proc;
        }

        return null;
    }

    pub fn deserialize(self: *ProgramTable) ![]u8 {
        var alloc_bytes = std.ArrayList(u8).init(self.alloc);

        try alloc_bytes.appendSlice([]u8{ 'x', 'N', 'Q', 0 });
        try alloc_bytes.append(self.name_len);
        try alloc_bytes.appendSlice(self.name);
        try alloc_bytes.appendSlice(self.allocations_len);

        for (self.allocations.items) |allocation| {
            try alloc_bytes.appendSlice(try allocation.deserialize(self.alloc));
        }

        try alloc_bytes.appendSlice(self.processes_len);

        for (self.processes.items) |proc| {
            try alloc_bytes.appendSlice(try proc.deserialize());
        }

        try alloc_bytes.appendSlice(self.instructions);

        return alloc_bytes.items;
    }
};

pub fn processCommand(alloc: std.mem.Allocator, instruction: []u8) ![][]u8 {
    var tmp_var = std.ArrayList(u8).init(alloc);
    var out = std.ArrayList([]u8).init(alloc);

    var should_process = true;
    var should_escape = false;

    for (instruction) |char| {
        if (char == '"') should_process = !should_process;
        if (char == '\\') should_escape = true;

        if (should_escape) {
            try tmp_var.append(char);
            should_escape = false;
        }

        if (should_process and char == ' ') {
            const copy = try alloc.alloc(u8, tmp_var.items.len);
            std.mem.copyForwards(u8, copy, tmp_var.items);

            try out.append(copy);

            tmp_var.clearAndFree();
        }

        try tmp_var.append(char);
    }

    if (tmp_var.items.len > 0) {
        const copy = try alloc.alloc(u8, tmp_var.items.len);
        std.mem.copyForwards(u8, copy, tmp_var.items);

        try out.append(copy);
    }

    return out.items;
}
