const std = @import("std");

pub const AstError = error{
    Unterminated,
    NotAnAst,
    ExpectedClosingParen,
};

pub const RuntimeError = error{
    OutOfBound,
    RuleNotFound,
};

// 统一的解析器错误类型，包含所有可能的错误
pub const ParserError = RuntimeError || AstError || std.mem.Allocator.Error;

/// 将输入中的 byte index 转换为行号、列号（均从 1 开始，便于用户阅读）
pub fn byteIndexToLineColumn(input: []const u8, index: usize) struct { line: usize, column: usize } {
    const end = @min(index, input.len);
    if (end == 0) {
        return .{ .line = 1, .column = 1 };
    }
    var line: usize = 1;
    var last_newline: usize = 0;
    for (input[0..end], 0..) |byte, i| {
        if (byte == '\n') {
            line += 1;
            last_newline = i + 1;
        }
    }
    // 列号 1-based：该行第一个字符为 1
    const column = (end - last_newline) + 1;
    return .{ .line = line, .column = column };
}

/// 根据完整输入、失败位置和期望描述，生成一条可读的错误信息（调用方负责 free 返回的切片）
pub fn formatFailureMessage(
    allocator: std.mem.Allocator,
    input: []const u8,
    position: usize,
    expected: ?[]const u8,
) ![]const u8 {
    const loc = byteIndexToLineColumn(input, position);
    if (expected) |exp| {
        return std.fmt.allocPrint(allocator, "at line {d} column {d} (position {d}): expected {s}", .{
            loc.line,
            loc.column,
            position,
            exp,
        });
    }
    return std.fmt.allocPrint(allocator, "at line {d} column {d} (position {d}): match failed", .{
        loc.line,
        loc.column,
        position,
    });
}
