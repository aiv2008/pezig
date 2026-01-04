const std = @import("std");
const Rule = @import("ast.zig").Rule;
const ast_errors = @import("errors.zig");
const MatchResult = @import("ast.zig").MatchResult;

//PEZParser中的input不是要翻译的字符串，而是规则字符串；
// 譬如 `a = {"b" ~ "c"}`整个规则字符串就是PEZParser的输入input
pub const PEZParser = struct {
    input: []const u8,
    position: usize,
    rules: std.StringHashMap(*Rule),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, input: []const u8) PEZParser {
        return PEZParser{
            .input = input,
            .position = 0,
            .rules = std.StringHashMap(*Rule).init(allocator),
            .allocator = allocator,
        };
    }

    // 主解析函数：解析整个 PEG 语法定义
    // 语法格式示例：
    //   rule1 = { "a" ~ "b" }
    //   rule2 = { "c" | "d" }
    pub fn parse(self: *PEZParser) !void {
        // 循环解析规则定义，直到输入结束
        while (!self.isAtEnd()) {
            self.skipWhitespace();

            // 如果遇到空行或注释，跳过
            if (self.isAtEnd()) {
                break;
            }

            // 解析一个规则定义
            const rule_def = try self.parseRuleDefinition();

            // 将规则存储到 HashMap 中
            try self.rules.put(rule_def.name, rule_def.rule);

            // 跳过规则定义后的空白字符
            self.skipWhitespace();
        }
    }

    // 第二步：实现辅助函数（跳过空白、读取字符等）
    // 1. 跳过空白字符（空格、\t、\n、\r）
    fn skipWhitespace(self: *PEZParser) void {
        while (!self.isAtEnd() and std.ascii.isWhitespace(self.input[self.position])) {
            self.position += 1;
        }
    }

    // 2. 检查是否到达输入末尾
    fn isAtEnd(self: *const PEZParser) bool {
        return self.position >= self.input.len;
    }

    // 3. 获取当前字符（不移动位置）
    fn peek(self: *const PEZParser) ?u8 {
        if (self.position < self.input.len) {
            return self.input[self.position];
        }
        return null;
    }

    // 解析标识符（规则名）
    // 4. 读取当前字符并移动位置
    fn advance(self: *PEZParser) ?u8 {
        if (self.position < self.input.len) {
            const pos = self.position;
            self.position += 1;
            return self.input[pos];
        }
        return null;
    }

    // 第三步：解析标识符（规则名），例如 "expression", "term123"
    // 返回值：解析出的标识符字符串，或 null（如果没有找到）
    pub fn parseIdentifier(self: *PEZParser) !?[]const u8 {
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
    pub fn parseString(self: *PEZParser) !?[]const u8 {
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
            return ast_errors.AstError.Unterminated;
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
    pub fn parseRuleDefinition(self: *PEZParser) ast_errors.ParserError!struct { name: []const u8, rule: *Rule } {
        // 1. 解析规则名（使用 parseIdentifier）
        self.skipWhitespace();
        const ident_opt = try self.parseIdentifier();
        const name_slice = ident_opt orelse return ast_errors.AstError.NotAnAst;

        // 复制规则名（因为 name_slice 只是指向原始输入的切片）
        const name = try self.allocator.dupe(u8, name_slice);

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

        // 4. 解析规则体（使用 parseExpression）
        const rule_ptr = try self.parseExpression();

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
    fn parsePrimary(self: *PEZParser) ast_errors.ParserError!*Rule {
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
                    return ast_errors.AstError.ExpectedClosingParen;
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
    fn parseExpression(self: *PEZParser) ast_errors.ParserError!*Rule {
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
    fn parseSequence(self: *PEZParser) ast_errors.ParserError!*Rule {
        // 实现
        // 1. 先解析一个序列（暂时先调用 parsePrimary）
        var left = try self.parsePostfix();
        // 2. 循环处理序列运算符 ~
        while (true) {
            self.skipWhitespace();
            if (self.peek() != '~') {
                break;
            }
            _ = self.advance(); // 跳过 '~'

            // 3. 解析右边的序列
            const right = try self.parsePostfix();

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
    fn parsePostfix(self: *PEZParser) ast_errors.ParserError!*Rule {
        var left = try self.parsePrefix();
        while (true) {
            self.skipWhitespace();
            switch (self.peek() orelse break) {
                '?' => {
                    //跳过?
                    _ = self.advance();
                    const optional_ptr = try self.allocator.create(Rule);
                    optional_ptr.* = Rule{
                        .optional = left,
                    };
                    left = optional_ptr;
                },
                '+' => {
                    //跳过+
                    _ = self.advance();
                    const repeat_ptr = try self.allocator.create(Rule);
                    repeat_ptr.* = Rule{ .repeat = .{
                        .rule = left,
                        .min = 1,
                        .max = null,
                    } };
                    left = repeat_ptr;
                },
                '*' => {
                    //跳过*
                    _ = self.advance();
                    const repeat_ptr = try self.allocator.create(Rule);
                    repeat_ptr.* = Rule{ .repeat = .{
                        .rule = left,
                        .min = 0,
                        .max = null,
                    } };
                    left = repeat_ptr;
                },
                else => {
                    break;
                },
            }
        }
        return left;
    }

    // 解析前缀操作符：!, &, _, @
    // 前缀操作符是右结合的，例如 !!a 会被解析为 !(!a)
    fn parsePrefix(self: *PEZParser) ast_errors.ParserError!*Rule {
        self.skipWhitespace();

        // 检查是否有前缀操作符
        const ch = self.peek() orelse return ast_errors.AstError.NotAnAst;

        switch (ch) {
            '!' => {
                _ = self.advance(); // 跳过 '!'
                const inner = try self.parsePrefix(); // 递归解析内部表达式
                const rule_ptr = try self.allocator.create(Rule);
                rule_ptr.* = Rule{ .not_predicate = inner };
                return rule_ptr;
            },
            '&' => {
                _ = self.advance(); // 跳过 '&'
                const inner = try self.parsePrefix(); // 递归解析内部表达式
                const rule_ptr = try self.allocator.create(Rule);
                rule_ptr.* = Rule{ .and_predicate = inner };
                return rule_ptr;
            },
            '_' => {
                _ = self.advance(); // 跳过 '_'
                const inner = try self.parsePrefix(); // 递归解析内部表达式
                const rule_ptr = try self.allocator.create(Rule);
                rule_ptr.* = Rule{ .silent = inner };
                return rule_ptr;
            },
            '@' => {
                _ = self.advance(); // 跳过 '@'
                const inner = try self.parsePrefix(); // 递归解析内部表达式
                const rule_ptr = try self.allocator.create(Rule);
                rule_ptr.* = Rule{ .atomic = inner };
                return rule_ptr;
            },
            else => {
                // 没有前缀操作符，直接解析基本元素
                return try self.parsePrimary();
            },
        }
    }

    // 释放单个 Rule 及其所有嵌套的规则
    fn freeRule(self: *PEZParser, rule: *Rule) void {
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

    // 释放 PEZParser 及其所有规则
    pub fn deinit(self: *PEZParser) void {
        // 释放所有规则和规则名
        var it = self.rules.iterator();
        while (it.next()) |entry| {
            // 释放规则名（HashMap 的 key，通过 allocator.dupe 分配）
            self.allocator.free(entry.key_ptr.*);

            // entry.value_ptr.* 获取 HashMap 中存储的 *Rule
            // 然后递归释放规则及其所有嵌套规则
            self.freeRule(entry.value_ptr.*);
        }
        self.rules.deinit();
    }
};

pub const RuntimeParser = struct {
    // 你需要定义哪些字段？
    // 1. rules - 存储规则的 HashMap
    // 2. allocator - 内存分配器

    // // 初始化函数
    // pub fn init(allocator: std.mem.Allocator, parser: *PEZParser) RuntimeParser {
    //     // TODO: 如何初始化？
    // }

    // // 主匹配方法：根据规则名匹配输入字符串
    // pub fn match(self: *RuntimeParser, rule_name: []const u8, input: []const u8) !*MatchResult {
    //     // TODO: 如何匹配？
    // }
};
