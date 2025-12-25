const std = @import("std");
const my_list = @import("my_list.zig");

pub const Stack = struct {
    list: my_list.List,

    pub fn new(allocator: std.mem.Allocator) Stack{
        return Stack{
            .list = try my_list.List.init(allocator),
        };
    }

    pub fn push(self: *Stack, data: i32) !void{
        try self.list.add(data);
    }

    pub fn pop(self: *Stack) !i32{
        self.list.del_tail();
        return try self.list.top();
    }

    pub fn print_stack(self: *Stack) void{
        self.list.print_list();
    }
    pub fn deinit(self: *Stack) void {
        self.list.deinit();
    }
};