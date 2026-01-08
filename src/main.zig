const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const Rule = @import("ast.zig").Rule;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== PEG 解析器测试 ===\n\n", .{});

    // // 测试 1: 简单的字面量规则
    // std.debug.print("测试 1: 解析简单规则\n", .{});
    // {
    //     const grammar = "hello = { \"world\" }";
    //     var parser = PEZParser.init(allocator, grammar);
    //     try parser.parse();
    //     defer parser.deinit();

    //     if (parser.rules.get("hello")) |rule| {
    //         std.debug.print("  规则 'hello' 解析成功\n", .{});
    //         std.debug.print("  规则类型: literal\n", .{});
    //         std.debug.print("  规则值: \"{s}\"\n\n", .{rule.literal});
    //     }
    // }

    // // 测试 2: 选择操作符
    // std.debug.print("测试 2: 解析选择操作符\n", .{});
    // {
    //     const grammar = "op = { \"+\" | \"-\" | \"*\" }";
    //     var parser = PEZParser.init(allocator, grammar);
    //     try parser.parse();
    //     defer parser.deinit();

    //     if (parser.rules.get("op")) |_| {
    //         std.debug.print("  规则 'op' 解析成功\n", .{});
    //         std.debug.print("  规则类型: choice\n\n", .{});
    //     }
    // }

    // // 测试 3: 序列操作符
    // std.debug.print("测试 3: 解析序列操作符\n", .{});
    // {
    //     const grammar = "ab = { \"a\" ~ \"b\" ~ \"c\" }";
    //     var parser = PEZParser.init(allocator, grammar);
    //     try parser.parse();
    //     defer parser.deinit();

    //     if (parser.rules.get("ab")) |_| {
    //         std.debug.print("  规则 'ab' 解析成功\n", .{});
    //         std.debug.print("  规则类型: sequence\n\n", .{});
    //     }
    // }

    // 测试 4: 复杂表达式
    std.debug.print("测试 4: 解析复杂表达式\n", .{});
    {
        const grammar =
            \\expression = { term ~ ("+" | "-") ~ term }
            \\term = { factor ~ ("*" | "/") ~ factor }
            \\factor = { number | "(" ~ expression ~ ")" }
            \\number = { ASCII_DIGIT+ }
        ;

        var parser = PEZParser.init(allocator, grammar);
        try parser.parse();
        defer parser.deinit();

        std.debug.print("  解析了 {d} 个规则:\n", .{parser.rules.count()});
        var it = parser.rules.iterator();
        while (it.next()) |entry| {
            std.debug.print("   key - {s}\n", .{entry.key_ptr.*});
            const value = entry.value_ptr.*;
            std.debug.print("value: \n", .{});
            value.*.parse();
        }
        std.debug.print("\n", .{});
    }

    // // 测试 5: 后缀操作符
    // std.debug.print("测试 5: 解析后缀操作符\n", .{});
    // {
    //     const grammar =
    //         \\opt = { "a"? }
    //         \\plus = { "b"+ }
    //         \\star = { "c"* }
    //     ;

    //     var parser = PEZParser.init(allocator, grammar);
    //     try parser.parse();
    //     defer parser.deinit();

    //     if (parser.rules.get("opt")) |_| {
    //         std.debug.print("  opt: optional\n", .{});
    //     }
    //     if (parser.rules.get("plus")) |_| {
    //         std.debug.print("  plus: repeat (min=1)\n", .{});
    //     }
    //     if (parser.rules.get("star")) |_| {
    //         std.debug.print("  star: repeat (min=0)\n", .{});
    //     }
    //     std.debug.print("\n", .{});
    // }

    // // 测试 6: 复杂操作
    // std.debug.print("测试 6: 复杂操作\n", .{});
    // {
    //     const grammar = "ab = { \"a\" ~ \"b\" ~ \"c\" }";

    //     var parser = PEZParser.init(allocator, grammar);
    //     try parser.parse();
    //     defer parser.deinit();

    //     std.debug.print("  解析了 {d} 个规则:\n", .{parser.rules.count()});
    //     var it = parser.rules.iterator();
    //     while (it.next()) |entry| {
    //         std.debug.print("{s}\n", .{entry.key_ptr.*});
    //         entry.value_ptr.*.parse();
    //     }
    //     // std.debug.print("\n", .{});
    // }

    std.debug.print("所有测试完成！\n", .{});
}
