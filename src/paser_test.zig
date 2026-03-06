const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const RuntimeParser = @import("parser.zig").RuntimeParser;
const Rule = @import("ast.zig").Rule;
const errors = @import("errors.zig");

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

test "parse regex in grammar: ~/pattern/ produces Rule.regex" {
    const allocator = std.testing.allocator;
    // 语法中 ~/\d+/ 表示正则，解析后应为 Rule.regex，pattern 为 \d+
    const grammar = "num = { ~/\\d+/ }";
    var parser = PEZParser.init(allocator, grammar);
    try parser.parse();
    defer parser.deinit();

    const rule_ptr = parser.rules.get("num").?;
    try std.testing.expect(rule_ptr.* == .regex);
    try std.testing.expectEqualStrings("\\d+", rule_ptr.regex);

    // 顺带验证：用该规则匹配输入
    var rp = RuntimeParser.init(allocator, parser.rules);
    const res = try rp.match("num", "42");
    defer {
        res.deinit();
        allocator.destroy(res);
    }
    try std.testing.expect(res.success);
    try std.testing.expectEqualStrings("42", res.matched_text);
}

// ---------- 错误与可观测性：失败用例与辅助函数测试 ----------

test "literal match failure: start_position and expected_rule_name" {
    const allocator = std.testing.allocator;
    const name = try allocator.dupe(u8, "hello");
    defer allocator.free(name);
    var rules = std.StringHashMap(*Rule).init(allocator);
    defer {
        var it = rules.iterator();
        while (it.next()) |e| allocator.destroy(e.value_ptr.*);
        rules.deinit();
    }
    const rule_ptr = try allocator.create(Rule);
    rule_ptr.* = .{ .literal = "world" };
    try rules.put(name, rule_ptr);

    var rp = RuntimeParser.init(allocator, rules);
    const res = try rp.match("hello", "hello");
    defer {
        res.deinit();
        allocator.destroy(res);
    }
    try std.testing.expect(!res.success);
    try std.testing.expectEqual(@as(usize, 0), res.start_position);
    try std.testing.expectEqual(@as(usize, 0), res.end_position);
    try std.testing.expect(res.expected_rule_name != null);
    try std.testing.expectEqualStrings("world", res.expected_rule_name.?);
}

test "repeat min not met: failure at current_pos" {
    const allocator = std.testing.allocator;
    const name = try allocator.dupe(u8, "a2");
    defer allocator.free(name);
    var rules = std.StringHashMap(*Rule).init(allocator);
    const lit = try allocator.create(Rule);
    lit.* = .{ .literal = "a" };
    const rule_ptr = try allocator.create(Rule);
    rule_ptr.* = .{ .repeat = .{ .rule = lit, .min = 2, .max = null } };
    try rules.put(name, rule_ptr);
    defer {
        allocator.destroy(lit);
        allocator.destroy(rule_ptr);
        rules.deinit();
    }

    var rp = RuntimeParser.init(allocator, rules);
    const res = try rp.match("a2", "a");
    defer {
        res.deinit();
        allocator.destroy(res);
    }
    try std.testing.expect(!res.success);
    try std.testing.expectEqual(@as(usize, 1), res.start_position);
}

test "byteIndexToLineColumn" {
    var loc = errors.byteIndexToLineColumn("", 0);
    try std.testing.expectEqual(@as(usize, 1), loc.line);
    try std.testing.expectEqual(@as(usize, 1), loc.column);

    loc = errors.byteIndexToLineColumn("ab", 0);
    try std.testing.expectEqual(@as(usize, 1), loc.line);
    try std.testing.expectEqual(@as(usize, 1), loc.column);

    loc = errors.byteIndexToLineColumn("ab", 1);
    try std.testing.expectEqual(@as(usize, 1), loc.line);
    try std.testing.expectEqual(@as(usize, 2), loc.column);

    loc = errors.byteIndexToLineColumn("a\nbc", 3);
    try std.testing.expectEqual(@as(usize, 2), loc.line);
    try std.testing.expectEqual(@as(usize, 2), loc.column);
}

test "formatFailureMessage" {
    const allocator = std.testing.allocator;
    const msg = try errors.formatFailureMessage(allocator, "a\nbc", 3, "digit");
    defer allocator.free(msg);
    try std.testing.expect(std.mem.indexOf(u8, msg, "line") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "column") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "digit") != null);

    const msg2 = try errors.formatFailureMessage(allocator, "xy", 1, null);
    defer allocator.free(msg2);
    try std.testing.expect(std.mem.indexOf(u8, msg2, "match failed") != null);
}
