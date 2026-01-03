const std = @import("std");

pub const AstError = error{
    Unterminated,
    NotAnAst,
    ExpectedClosingParen,
};

// 统一的解析器错误类型，包含所有可能的错误
pub const ParserError = AstError || std.mem.Allocator.Error;
