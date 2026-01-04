const std = @import("std");

pub const AstError = error{
    Unterminated,
    NotAnAst,
    ExpectedClosingParen,
};

pub const RuntimeError = error{
    OutOfBound,
};

// 统一的解析器错误类型，包含所有可能的错误
pub const ParserError = RuntimeError || AstError || std.mem.Allocator.Error;
