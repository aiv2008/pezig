const std = @import("std");
const ast_errors = @import("errors.zig");
const stack = @import("stack.zig");

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
    pub fn parse(self: *Rule) void {
        switch (self.*) {
            .literal => |value| {
                std.debug.print("literal: ", .{});
                std.debug.print("{s}", .{value});
            },
            .regex => |value| {
                std.debug.print("regex: ", .{});
                std.debug.print("{s}", .{value});
            },
            .rule_ref => |value| {
                std.debug.print("rule_ref: ", .{});
                std.debug.print("{s}", .{value});
            },
            .sequence => |value| {
                std.debug.print("sequence: ", .{});
                std.debug.print("left: ", .{});
                value.left.*.parse();
                std.debug.print("right", .{});
                value.right.*.parse();
            },
            .choice => |value| {
                std.debug.print("choice: ", .{});
                std.debug.print("left: ", .{});
                value.left.*.parse();
                std.debug.print("right", .{});
                value.right.*.parse();
            },
            .optional => |value| {
                std.debug.print("optional: ", .{});
                value.*.parse();
            },
            .repeat => |value| {
                std.debug.print("repeat: ", .{});
                std.debug.print("value: ", .{});
                value.rule.*.parse();
                if (value.max) |max_val| {
                    std.debug.print("max: {d}", .{max_val});
                } else {
                    std.debug.print("max: null", .{});
                }
                std.debug.print("min: {d}", .{value.min});
            },

            // // 否定前瞻：!A（不匹配 A）
            //     not_predicate: *Rule,
            .not_predicate => |value| {
                std.debug.print("not_predicate: ", .{});
                value.*.parse();
            },
            //     // 肯定前瞻：&A（匹配 A 但不消耗）
            //     and_predicate: *Rule,
            .and_predicate => |value| {
                std.debug.print("and_predicate: ", .{});
                value.*.parse();
            },
            //     // 静默：_A（匹配但不捕获）
            //     silent: *Rule,
            .silent => |value| {
                std.debug.print("silent: ", .{});
                value.*.parse();
            },
            //     // 原子：@A（禁用回溯）
            //     atomic: *Rule,
            .atomic => |value| {
                std.debug.print("atomic: ", .{});
                value.*.parse();
            },
            //     // 优先级组
            //     precedence: struct {
            //         rules: []Rule,
            //         levels: []PrecedenceLevel,
            //     },
            .precedence => {},
        }
    }
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
