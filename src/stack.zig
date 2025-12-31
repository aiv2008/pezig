const std = @import("std");

pub fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .items = std.ArrayList(T).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.items.deinit();
        }

        pub fn push(self: *@This(), item: T) !void {
            try self.items.append(item);
        }

        pub fn pop(self: *@This()) ?T {
            return self.items.popOrNull();
        }

        pub fn peek(self: *@This()) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[self.items.items.len - 1];
        }

        pub fn isEmpty(self: *@This()) bool {
            return self.items.items.len == 0;
        }
    };
}
