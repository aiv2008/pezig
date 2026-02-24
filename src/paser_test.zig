const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const RuntimeParser = @import("parser.zig").RuntimeParser;
const Rule = @import("ast.zig").Rule;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    std.debug.print("测试 31111: 解析序列操作符\n", .{});
    {
        const grammar =
            // \\ab = { a ~ b ~ c }
            // \\a = {"oh, "}
            // \\b = {"hello "}
            // \\c = {"world"}
            \\ ab = { @a | b }
            \\ a = { "hello" }
            \\ b = { "hell" }
        ;
        // const grammar = "ab = { \"a\" ~ \"b\" ~ \"c\" }";
        var parser = PEZParser.init(allocator, grammar);
        try parser.parse();
        defer parser.deinit();

        if (parser.rules.get("ab")) |_| {
            std.debug.print("  规则 'ab' 解析成功\n", .{});
            std.debug.print("  规则类型: sequence\n\n", .{});
        }

        var runtimeParser = RuntimeParser.init(allocator, parser.rules);
        // const matchResult = try runtimeParser.match("ab", "oh, hello worl");
        const matchResult = try runtimeParser.match("ab", "hell");
        defer {
            matchResult.deinit();
            allocator.destroy(matchResult);
        }
        std.debug.print("success: {}\n", .{matchResult.success});
    }
}

test "matchRegex 函数直接调用" {
    std.debug.print("[test] matchRegex 函数直接调用\n", .{});
    const allocator = std.testing.allocator;
    var rules = std.StringHashMap(*Rule).init(allocator);
    defer rules.deinit();
    var rp = RuntimeParser.init(allocator, rules);
    const res = try rp.matchRegex("\\d+", "123", 0);
    defer {
        res.deinit();
        allocator.destroy(res);
    }
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(usize, 0), res.start_position);
    try std.testing.expectEqual(@as(usize, 3), res.end_position);
    try std.testing.expectEqualStrings("123", res.matched_text);
}

test "matchRegex: 从开头匹配数字" {
    std.debug.print("[test] matchRegex: 从开头匹配数字\n", .{});
    const allocator = std.testing.allocator;
    const name = try allocator.dupe(u8, "num");
    defer allocator.free(name);
    var rules = std.StringHashMap(*Rule).init(allocator);
    defer {
        var it = rules.iterator();
        while (it.next()) |e| {
            allocator.destroy(e.value_ptr.*);
        }
        rules.deinit();
    }
    const rule_ptr = try allocator.create(Rule);
    rule_ptr.* = .{ .regex = "\\d+" };
    try rules.put(name, rule_ptr);

    var rp = RuntimeParser.init(allocator, rules);

    // 从开头匹配应成功
    const res_ok = try rp.match("num", "123");
    defer {
        res_ok.deinit();
        allocator.destroy(res_ok);
    }
    try std.testing.expect(res_ok.success);
    try std.testing.expectEqual(@as(usize, 0), res_ok.start_position);
    try std.testing.expectEqual(@as(usize, 3), res_ok.end_position);
    try std.testing.expectEqualStrings("123", res_ok.matched_text);

    // 无数字应失败
    const res_fail = try rp.match("num", "abc");
    defer {
        res_fail.deinit();
        allocator.destroy(res_fail);
    }
    try std.testing.expect(!res_fail.success);

    // 匹配不在开头应失败（PEG：只在 pos 处匹配）
    const res_no_prefix = try rp.match("num", "x123");
    defer {
        res_no_prefix.deinit();
        allocator.destroy(res_no_prefix);
    }
    try std.testing.expect(!res_no_prefix.success);
}

test "matchRegex: 从 pos>0 匹配" {
    std.debug.print("[test] matchRegex: 从 pos>0 匹配\n", .{});
    const allocator = std.testing.allocator;
    const name = try allocator.dupe(u8, "num");
    defer allocator.free(name);
    var rules = std.StringHashMap(*Rule).init(allocator);
    defer {
        var it = rules.iterator();
        while (it.next()) |e| allocator.destroy(e.value_ptr.*);
        rules.deinit();
    }
    const rule_ptr = try allocator.create(Rule);
    rule_ptr.* = .{ .regex = "\\d+" };
    try rules.put(name, rule_ptr);

    var rp = RuntimeParser.init(allocator, rules);
    const res = try rp.matchResult(rule_ptr, "x123", 1);
    defer {
        res.deinit();
        allocator.destroy(res);
    }
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(usize, 1), res.start_position);
    try std.testing.expectEqual(@as(usize, 4), res.end_position);
    try std.testing.expectEqualStrings("123", res.matched_text);
}
