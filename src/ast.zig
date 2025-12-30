const std = @import("std");
const ast_errors = @import("errors.zig");

pub const Rule = union(enum) {
    // 字面量匹配
    literal: []const u8,

    // 正则表达式匹配
    regex: []const u8,

    // 规则引用
    rule_ref: []const u8,

    // 序列：A ~ B（A 后跟 B）
    sequence: struct {
        left: *Rule,
        right: *Rule,
    },

    // 选择：A | B（A 或 B，有序）
    choice: struct {
        left: *Rule,
        right: *Rule,
    },

    // 可选：A?
    optional: *Rule,

    // 重复：A+ 或 A*
    repeat: struct {
        rule: *Rule,
        // 最少次数
        min: usize,
        // 最多次数（null 表示无限制）
        max: ?usize,
    },

    // 否定前瞻：!A（不匹配 A）
    not_predicate: *Rule,

    // 肯定前瞻：&A（匹配 A 但不消耗）
    and_predicate: *Rule,

    // 静默：_A（匹配但不捕获）
    silent: *Rule,

    // 原子：@A（禁用回溯）
    atomic: *Rule,

    // 优先级组
    precedence: struct {
        rules: []Rule,
        levels: []PrecedenceLevel,
    },
};

/// 2. 规则对象（Rule AST）
/// 优先级组
pub const PrecedenceLevel = struct {
    level: u8,
    associativity: enum { left, right, none },
    rule: *Rule,
};

pub const MatchResult = struct {
    success: bool,
    start_position: usize,
    end_position: usize,
    matched_text: []const u8,
    children: std.ArrayList(*MatchResult),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, start: usize, end: usize, text: []const u8) !MatchResult {
        return MatchResult{
            .allocator = allocator,
            .start_position = start,
            .end_position = end,
            .matched_text = text,
            .success = true,
            .children = std.ArrayList(*MatchResult).init(allocator),
        };
    }
};

pub const PEGParser = struct {
    input: []const u8,
    position: usize,
    rules: std.StringHashMap(*Rule),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, input: []const u8) PEGParser {
        return PEGParser{
            .input = input,
            .position = 0,
            .rules = std.StringHashMap(*Rule).init(allocator),
            .allocator = allocator,
        };
    }

    // 第二步：实现辅助函数（跳过空白、读取字符等）
    // 1. 跳过空白字符（空格、\t、\n、\r）
    fn skipWhitespace(self: *PEGParser) void {
        while (!self.isAtEnd() and std.ascii.isWhitespace(self.input[self.position])) {
            self.position += 1;
        }
    }

    // 2. 检查是否到达输入末尾
    fn isAtEnd(self: *const PEGParser) bool {
        return self.position >= self.input.len;
    }

    // 3. 获取当前字符（不移动位置）
    fn peek(self: *const PEGParser) ?u8 {
        if (self.position < self.input.len) {
            return self.input[self.position];
        }
        return null;
    }

    // 解析标识符（规则名）
    // 4. 读取当前字符并移动位置
    fn advance(self: *PEGParser) ?u8 {
        if (self.position < self.input.len) {
            const pos = self.position;
            self.position += 1;
            return self.input[pos];
        }
        return null;
    }

    // 第三步：解析标识符（规则名），例如 "expression", "term123"
    // 返回值：解析出的标识符字符串，或 null（如果没有找到）
    pub fn parseIdentifier(self: *PEGParser) !?[]const u8 {
        // 1. 先跳过空白字符
        self.skipWhitespace();

        // 2. 检查是否到达末尾
        if (self.isAtEnd()) return null;

        // 3. 检查当前字符是否是字母或下划线（必须以字母或下划线开头）
        const first_char = self.input[self.position];
        if (!std.ascii.isAlphabetic(first_char) and first_char != '_') {
            return null;
        }

        // 4. 记录开始位置并移动位置
        const start_pos = self.position;
        self.position += 1;

        // 5. 继续读取字母、数字或下划线
        while (!self.isAtEnd()) {
            const ch = self.input[self.position];
            if (std.ascii.isAlphanumeric(ch) or ch == '_') {
                self.position += 1;
            } else {
                break;
            }
        }

        return self.input[start_pos..self.position];
    }

    // 第四步：解析字面量字符串，例如: "hello", "+", "-"
    // 支持双引号包围的字符串
    pub fn parseString(self: *PEGParser) !?[]const u8 {
        // 1. 跳过空白字符
        self.skipWhitespace();

        // 2. 检查是否到达末尾
        if (self.isAtEnd()) return null;

        // 3. 检查当前字符是否是双引号 '"'
        if (self.input[self.position] != '"') {
            return null;
        }

        // 4. 跳过开始的引号并记录字符串开始位置
        self.position += 1;
        const start_pos = self.position;

        // 5. 读取字符直到遇到结束的双引号
        while (!self.isAtEnd()) {
            if (self.peek() == '"') {
                break;
            }
            self.position += 1;
        }

        // 6. 检查是否找到了结束引号
        if (self.isAtEnd()) {
            // 字符串没有闭合，返回错误（或者可以返回null，取决于设计）
            return error.UnterminatedString;
        }

        // 7. 记录结束位置（遇到结束引号的位置）
        const end_pos = self.position;

        // 8. 跳过结束的引号
        self.position += 1;

        // 9. 返回引号内的字符串（不包括引号本身）
        return self.input[start_pos..end_pos];
    }

    // 第五步：解析规则定义
    // PEG 语法格式：rule_name = { rule_body }
    // 例如：expression = { term ~ ("+" | "-") ~ term }
    // 思考：
    // 如何识别规则定义的各个部分？
    // 规则名（identifier）
    // =
    // {
    // 规则体（表达式）
    // }
    // 解析顺序：
    // 解析规则名
    // 跳过空白，匹配 =
    // 跳过空白，匹配 {
    // 解析规则体（表达式，下一步实现）
    // 匹配 }
    // 任务：实现 parseRuleDefinition 函数
    // 解析完整的规则定义，例如: expression = { term ~ ("+" | "-") ~ term }
    // 返回值：规则名和规则体的元组，或错误
    pub fn parseRuleDefinition(self: *PEGParser) !struct { name: []const u8, rule: *Rule } {
        // 1. 解析规则名（使用 parseIdentifier）
        self.skipWhitespace();
        const ident_opt = try self.parseIdentifier();
        const name = ident_opt orelse return ast_errors.AstError.NotAnAst;

        // 2. 跳过空白，检查并跳过 '='
        self.skipWhitespace();
        if (self.peek() != '=') {
            return ast_errors.AstError.NotAnAst;
        }
        _ = self.advance(); // 跳过 '='

        // 3. 跳过空白，检查并跳过 '{'
        self.skipWhitespace();
        if (self.peek() != '{') {
            return ast_errors.AstError.NotAnAst;
        }
        _ = self.advance(); // 跳过 '{'

        // 4. 暂时先创建一个简单的占位规则（下一步再实现解析规则体）
        // 注意：需要分配内存，因为返回的是 *Rule
        const rule_ptr = try self.allocator.create(Rule);
        rule_ptr.* = Rule{ .literal = "TODO" };

        // 5. 跳过空白，查找并跳过 '}'
        self.skipWhitespace();
        if (self.peek() != '}') {
            return ast_errors.AstError.NotAnAst;
        }
        _ = self.advance(); // 跳过 '}'

        // 6. 返回结构体（匿名结构体字面量语法）
        return .{
            .name = name,
            .rule = rule_ptr,
        };
    }

    // 解析基本元素（字面量、规则引用、括号表达式）
    // parsePrimary 解析基本元素：
    // - 字符串字面量（如 "hello"）
    // - 规则引用（如 expression）
    // - 括号表达式（如 ( ... )）
    fn parsePrimary(self: *PEGParser) !*Rule {
        // 1. 跳过空白
        self.skipWhitespace();

        // 2. 检查是否是字符串字面量（以 " 开头）

        if (self.peek()) |ch| {
            if (ch == '"') {
                // 调用 parseString，创建 literal 规则
                const str_opt = try self.parseString();
                const str = str_opt orelse return ast_errors.AstError.Unterminated;
                const str_copy = try self.allocator.dupe(u8, str);
                const rule_ptr = try self.allocator.create(Rule);
                rule_ptr.* = Rule{ .literal = str_copy };
                return rule_ptr;
            }

            // 3. 检查是否是括号表达式（以 ( 开头）
            if (ch == '(') {
                _ = self.advance(); // 跳过 '('
                const rule_ptr = try self.parseExpression();

                // 跳过 ')'
                self.skipWhitespace();
                if (self.peek() != ')') {
                    return error.ExpectedClosingParen;
                }
                _ = self.advance();
                return rule_ptr;
            }
        }

        // 4. 否则，尝试解析标识符（规则引用）
        const ident_opt = try self.parseIdentifier();
        if (ident_opt) |name| {
            const rule_ptr = try self.allocator.create(Rule);
            const name_copy = try self.allocator.dupe(u8, name);
            rule_ptr.* = Rule{ .rule_ref = name_copy };
            return rule_ptr;
        }

        // 5. 如果都不是，返回错误
        return ast_errors.AstError.NotAnAst;
    }

    // 思路：
    // 先解析一个序列（parseSequence，稍后实现，先用占位符）
    // 循环检查是否有 |
    // 如果有，解析下一个序列，构建 choice 规则
    // 返回最终的规则
    fn parseExpression(self: *PEGParser) !*Rule {
        // 1. 先解析一个序列（暂时先调用 parsePrimary）
        var left = try self.parseSequence();

        // 2. 循环处理选择运算符 |
        while (true) {
            self.skipWhitespace();
            if (self.peek() != '|') {
                break;
            }
            _ = self.advance(); // 跳过 '|'

            // 3. 解析右边的序列
            const right = try self.parseSequence();

            // 4. 创建 choice 规则
            const choice_ptr = try self.allocator.create(Rule);
            choice_ptr.* = Rule{ .choice = .{
                .left = left,
                .right = right,
            } };

            left = choice_ptr;
        }

        return left;
    }

    // parseSequence 处理序列运算符 ~（或隐式序列）。
    fn parseSequence(self: *PEGParser) !*Rule {
        // 实现
        // 1. 先解析一个序列（暂时先调用 parsePrimary）
        var left = try self.parsePrimary();
        // 2. 循环处理序列运算符 ~
        while (true) {
            self.skipWhitespace();
            if (self.peek() != '~') {
                break;
            }
            _ = self.advance(); // 跳过 '~'

            // 3. 解析右边的序列
            const right = try self.parsePrimary();

            // 4. 创建 sequence  规则
            const sequence_ptr = try self.allocator.create(Rule);
            sequence_ptr.* = Rule{ .sequence = .{
                .left = left,
                .right = right,
            } };

            left = sequence_ptr;
        }

        return left;
    }

    // 解析后缀操作符
    // parsePostfix 应能解析：
    // "a" → 字面量 "a"
    // "a"? → 可选：optional("a")
    // "a"+ → 一次或多次：repeat("a", min=1)
    // "a"* → 零次或多次：repeat("a", min=0)
    // "a"?+ → 多重后缀：先 ? 后 +
    fn parsePostfix(self: *PEGParser) !Rule {
        // var left = try self.parsePrimary();
        // while (true) {
        //     self.skipWhitespace();
        // }
        return error.Unterminated;
    }

    // 释放单个 Rule 及其所有嵌套的规则
    fn freeRule(self: *PEGParser, rule: *Rule) void {
        switch (rule.*) {
            // 对于包含指针的 Rule，需要递归释放
            .sequence => |seq| {
                self.freeRule(seq.left);
                self.freeRule(seq.right);
                self.allocator.destroy(rule);
            },
            .choice => |ch| {
                self.freeRule(ch.left);
                self.freeRule(ch.right);
                self.allocator.destroy(rule);
            },
            .optional => |opt| {
                self.freeRule(opt);
                self.allocator.destroy(rule);
            },
            .repeat => |rep| {
                self.freeRule(rep.rule);
                self.allocator.destroy(rule);
            },
            .not_predicate => |pred| {
                self.freeRule(pred);
                self.allocator.destroy(rule);
            },
            .and_predicate => |pred| {
                self.freeRule(pred);
                self.allocator.destroy(rule);
            },
            .silent => |silent| {
                self.freeRule(silent);
                self.allocator.destroy(rule);
            },
            .atomic => |atomic| {
                self.freeRule(atomic);
                self.allocator.destroy(rule);
            },
            .precedence => |prec| {
                // precedence 中的 rules 是 []Rule（值类型），不需要单独释放
                // 但需要释放 levels 中的 rule 指针
                for (prec.levels) |level| {
                    self.freeRule(level.rule);
                }
                self.allocator.free(prec.rules);
                self.allocator.free(prec.levels);
                self.allocator.destroy(rule);
            },
            // 对于包含字符串的类型，需要先释放字符串，再释放 Rule
            .literal => |str| {
                self.allocator.free(str); // 释放字符串（通过 dupe 分配）
                self.allocator.destroy(rule); // 释放 Rule 本身
            },
            .regex => |str| {
                self.allocator.free(str); // 释放字符串
                self.allocator.destroy(rule);
            },
            .rule_ref => |name| {
                self.allocator.free(name); // 释放规则名字符串
                self.allocator.destroy(rule);
            },
        }
    }

    // 释放 PEGParser 及其所有规则
    pub fn deinit(self: *PEGParser) void {
        // 释放所有规则
        var it = self.rules.iterator();
        while (it.next()) |entry| {
            // entry.value_ptr.* 获取 HashMap 中存储的 *Rule
            // 然后递归释放规则及其所有嵌套规则
            self.freeRule(entry.value_ptr.*);
        }
        self.rules.deinit();
    }
};
