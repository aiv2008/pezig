const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
// ============================================================================
// 测试代码
// ============================================================================

test "parse simple literal rule" {
    const gpa = std.testing.allocator;
    const grammar = "hello = { \"world\" }";

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    // 检查规则是否存在
    try std.testing.expect(parser.rules.contains("hello"));

    // 检查规则类型
    const rule = parser.rules.get("hello").?;
    try std.testing.expect(rule.* == .literal);
    try std.testing.expectEqualStrings("world", rule.literal);
}

test "parse choice rule" {
    const gpa = std.testing.allocator;
    const grammar = "op = { \"+\" | \"-\" }";

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    const rule = parser.rules.get("op").?;
    try std.testing.expect(rule.* == .choice);
    try std.testing.expect(rule.choice.left.* == .literal);
    try std.testing.expectEqualStrings("+", rule.choice.left.literal);
    try std.testing.expect(rule.choice.right.* == .literal);
    try std.testing.expectEqualStrings("-", rule.choice.right.literal);
}

test "parse sequence rule" {
    const gpa = std.testing.allocator;
    const grammar = "ab = { \"a\" ~ \"b\" }";

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    const rule = parser.rules.get("ab").?;
    try std.testing.expect(rule.* == .sequence);
    try std.testing.expect(rule.sequence.left.* == .literal);
    try std.testing.expectEqualStrings("a", rule.sequence.left.literal);
    try std.testing.expect(rule.sequence.right.* == .literal);
    try std.testing.expectEqualStrings("b", rule.sequence.right.literal);
}

test "parse postfix operators" {
    const gpa = std.testing.allocator;
    const grammar =
        \\opt = { "a"? }
        \\one_or_more = { "a"+ }
        \\zero_or_more = { "a"* }
    ;

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    // 测试可选
    const opt_rule = parser.rules.get("opt").?;
    try std.testing.expect(opt_rule.* == .optional);

    // 测试一次或多次
    const plus_rule = parser.rules.get("one_or_more").?;
    try std.testing.expect(plus_rule.* == .repeat);
    try std.testing.expect(plus_rule.repeat.min == 1);
    try std.testing.expect(plus_rule.repeat.max == null);

    // 测试零次或多次
    const star_rule = parser.rules.get("zero_or_more").?;
    try std.testing.expect(star_rule.* == .repeat);
    try std.testing.expect(star_rule.repeat.min == 0);
    try std.testing.expect(star_rule.repeat.max == null);
}

test "parse prefix operators" {
    const gpa = std.testing.allocator;
    const grammar =
        \\not = { !"a" }
        \\and = { &"a" }
        \\silent = { _"a" }
        \\atomic = { @"a" }
    ;

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    try std.testing.expect(parser.rules.get("not").?.* == .not_predicate);
    try std.testing.expect(parser.rules.get("and").?.* == .and_predicate);
    try std.testing.expect(parser.rules.get("silent").?.* == .silent);
    try std.testing.expect(parser.rules.get("atomic").?.* == .atomic);
}

test "parse rule reference" {
    const gpa = std.testing.allocator;
    const grammar =
        \\a = { "a" }
        \\b = { a }
    ;

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    const rule = parser.rules.get("b").?;
    try std.testing.expect(rule.* == .rule_ref);
    try std.testing.expectEqualStrings("a", rule.rule_ref);
}

test "parse parentheses" {
    const gpa = std.testing.allocator;
    const grammar = "expr = { ( \"a\" | \"b\" ) }";

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    const rule = parser.rules.get("expr").?;
    try std.testing.expect(rule.* == .choice);
}

test "parse multiple rules" {
    const gpa = std.testing.allocator;
    const grammar =
        \\expr = { term ~ ("+" | "-") ~ term }
        \\term = { "number" }
    ;

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    try std.testing.expect(parser.rules.contains("expr"));
    try std.testing.expect(parser.rules.contains("term"));

    const expr_rule = parser.rules.get("expr").?;
    try std.testing.expect(expr_rule.* == .sequence);
}

test "parse complex expression" {
    const gpa = std.testing.allocator;
    const grammar =
        \\expression = { term ~ ("+" | "-") ~ term }
        \\term = { factor ~ ("*" | "/") ~ factor }
        \\factor = { number | "(" ~ expression ~ ")" }
        \\number = { ASCII_DIGIT+ }
    ;

    var parser = PEZParser.init(gpa, grammar);
    try parser.parse();
    defer parser.deinit();

    try std.testing.expect(parser.rules.contains("expression"));
    try std.testing.expect(parser.rules.contains("term"));
    try std.testing.expect(parser.rules.contains("factor"));
    try std.testing.expect(parser.rules.contains("number"));
}
