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