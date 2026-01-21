const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const RuntimeParser = @import("parser.zig").RuntimeParser;

pub fn main() !void{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    std.debug.print("测试1", .{});
    {
        const grammar = "hello = { \"world\" }";
        var parser = PEZParser.init(allocator, grammar);
        try parser.parse();
        defer parser.deinit();

        if (parser.rules.get("hello")) |rule| {
            std.debug.print("  规则 'hello' 解析成功\n", .{});
            std.debug.print("  规则类型: literal\n", .{});
            std.debug.print("  规则值: \"{s}\"\n\n", .{rule.literal});
        }
        const s = "world";
        const s2 = "worl";
        const runtime_parser = RuntimeParser.init(allocator, parser.rules);
        const result1 = try runtime_parser.match("hello", s);
        const result2 = try runtime_parser.match("hello", s2);
        std.debug.print("result1 = {d}", .{result1.success});
        std.debug.print("result2 = {d}", .{result2.success});
    }
}