const std = @import("std");

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
        min: usize,      // 最少次数
        max: ?usize,     // 最多次数（null 表示无限制）
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
    pub fn init(allocator: std.mem.Allocator,start: usize, end: usize, text: []const u8) !MatchResult{
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
    rules: std.StringHashMap(Rule),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, input: []const u8) PEGParser{
        return PEGParser{
            .input = input,
            .position = 0,
            .rules = std.StringHashMap(Rule).init(allocator),
            .allocator = allocator,
        };
    }

    // 第二步：实现辅助函数（跳过空白、读取字符等）
    // 1. 跳过空白字符（空格、\t、\n、\r）
    fn skipWhitespace(self: *PEGParser) void{
        while (!self.isAtEnd() and std.ascii.isWhitespace(self.input[self.position])) {
            self.position += 1;
        }
    }

    // 2. 检查是否到达输入末尾
    fn isAtEnd(self: *const PEGParser) bool{
        return self.position >= self.input.len;
    }

    // 3. 获取当前字符（不移动位置）
    fn peek(self: *const PEGParser) ?u8{
        if(self.position < self.input.len){
            return self.input[self.position];
        }
        return null;
    }

    // 解析标识符（规则名）
    // 4. 读取当前字符并移动位置
    fn advance(self: *PEGParser) ?u8{
        if(self.position < self.input.len){
            const pos = self.position;
            self.position += 1;
            return self.input[pos];
        }
        return null;
    }

    // 第三步：解析标识符（规则名），例如 "expression", "term123"
    // 返回值：解析出的标识符字符串，或 null（如果没有找到）
    pub fn parseIdentifier(self: *PEGParser) !?[] const u8{
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
    pub fn parseString(self: *PEGParser) !?[]const u8{
        // 1. 跳过空白字符
        self.skipWhitespace();
        
        // 2. 检查是否到达末尾
        if (self.isAtEnd()) return null;
        
        // 3. 检查当前字符是否是双引号 '"'
        if(self.input[self.position] != '"'){
            return null;
        }
        
        // 4. 跳过开始的引号并记录字符串开始位置
        self.position += 1;
        const start_pos = self.position;
        
        // 5. 读取字符直到遇到结束的双引号
        while(!self.isAtEnd()){
            if(self.peek() == '"'){
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
};