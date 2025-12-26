const std = @import("std");
const root = @import("root.zig");
const my_list = @import("my_list.zig");
const my_stack = @import("stack.zig");
pub fn main() !void{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stack = my_stack.Stack.new(allocator);
    defer{
        stack.deinit();
    }
    try stack.push(1);
    try stack.push(2);
    try stack.push(3);
    try stack.push(4);
    _ = try stack.pop();
    // stack.print_stack();
    const iter = stack.list.iterator();
    while (iter.next()) |ptr| {
        std.debug.print("{}", .{ptr.data});
    }

    // var list = try my_list.List.init(allocator);
    // defer {
    //     list.deinit();  // 释放所有 Node
    // }
    // const list_ptr = &list;
    
    // try list.add(1);
    // try list.add(2);
    // try list.add(3);
    // try list.add(3);
    // try list_ptr.add(4);  // 修正：使用实例方法调用
    // list_ptr.del_tail();
    // list_ptr.del_tail();
    // list_ptr.del_tail();
    // list_ptr.del_tail();
    // // list_ptr.del_tail();
    // // list.print_list();
    // var iter = list_ptr.iterator();
    // while (iter.next()) |ptr| {
    //     std.debug.print("{}", .{ptr.data});
    // }

}
