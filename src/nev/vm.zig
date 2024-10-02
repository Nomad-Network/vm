const C = @import("c.zig");
const std = @import("std");
const Object = @import("object.zig").Object;

const GPA = std.heap.GeneralPurposeAllocator(.{});

pub const VMError = error{FailedExecution};
pub const ProgramError = error{ FailedExecution, FailedCompilation, FailedRoutineInitialisation };

pub const Program = struct {
    ptr: [*c]C._nev.program,
    gpa: *GPA,
    vm: *VM,

    pub fn new(vm: *VM) Program {
        const ptr = C._nev.program_new();
        return Program{ .ptr = ptr, .gpa = @constCast(&GPA{}), .vm = vm };
    }

    pub fn compile(self: Program, code: []u8) ProgramError!void {
        const c_code = C.stringToCString(std.heap.c_allocator, code) catch return ProgramError.FailedCompilation;
        const exit_code = C._nev.nev_compile_str(c_code.ptr, self.ptr);

        switch (exit_code) {
            0 => return,
            else => return ProgramError.FailedCompilation,
        }
    }

    pub fn call(self: Program, routine: []u8, args: []Object) ProgramError!Object {
        try self.prepare(routine);

        for (args, 0..) |arg, i| {
            self.ptr.*.params[i] = arg.ptr.*;
        }

        const result = Object.new() catch return ProgramError.FailedExecution;

        return switch (C._nev.nev_execute(self.ptr, self.vm.ptr, result.ptr)) {
            0 => result,
            else => ProgramError.FailedExecution,
        };
    }

    pub fn deinit(self: Program) void {
        C._nev.program_delete(self.ptr);
    }

    fn prepare(self: Program, routine: []u8) ProgramError!void {
        const c_routine = self.gpa.allocator().allocSentinel(u8, routine.len, 0) catch return ProgramError.FailedCompilation;
        std.mem.copyForwards(u8, c_routine, routine);

        switch (C._nev.nev_prepare(self.ptr, c_routine.ptr)) {
            0 => return,
            else => return ProgramError.FailedRoutineInitialisation,
        }
    }
};

pub const VM = struct {
    ptr: [*c]C._nev.vm,

    pub fn new(mem_size: u32, stack_size: u32) VM {
        return VM{
            .ptr = C._nev.vm_new(
                @as(c_uint, mem_size),
                @as(c_uint, stack_size),
            ),
        };
    }

    pub fn program(self: *VM) Program {
        return Program.new(self);
    }

    pub fn print_stack_trace(vm: VM) void {
        C._nev.vm_print_stack_trace(vm.ptr);
    }

    pub fn deinit(self: VM) void {
        C._nev.vm_delete(self.ptr);
    }
};
