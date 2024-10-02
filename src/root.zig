//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const nev = @import("nev/nev.zig");

pub const VM = nev.VM;
pub const Object = nev.Object;
pub const Program = nev.Program;
pub const C = nev.C;
pub const Package = @import("package.zig").ExecutionPackage;
pub const utils = @import("util.zig");
