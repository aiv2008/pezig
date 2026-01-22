const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const RuntimeParser = @import("parser.zig").RuntimeParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    std.debug.print("测试1\n", .{});
    {
        const grammar = "hello = { \"world\" }";
        var parser = PEZParser.init(allocator, grammar);
        try parser.parse();
        // defer parser.deinit();

        if (parser.rules.get("hello")) |rule| {
            std.debug.print("  规则 'hello' 解析成功\n", .{});
            std.debug.print("  规则类型: literal\n", .{});
            std.debug.print("  规则值: \"{s}\"\n\n", .{rule.literal});
        }
        const s = "world";
        const s2 = "worl";
        var runtime_parser = RuntimeParser.init(allocator, parser.rules);
        // 注意：runtime_parser 不需要调用 deinit()，因为它只是共享规则
        // 规则的所有权属于 parser，由 parser.deinit() 负责释放
        defer parser.deinit(); // 释放规则对象和 HashMap
        
        const result1 = try runtime_parser.match("hello", s);
        defer {
            result1.deinit();
            allocator.destroy(result1);
        }
        
        const result2 = try runtime_parser.match("hello", s2);
        defer {
            result2.deinit();
            allocator.destroy(result2);
        }
        
        std.debug.print("result1 = {}\n", .{result1.success});
        std.debug.print("result2 = {}\n", .{result2.success});
    }
}
