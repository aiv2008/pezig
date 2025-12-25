//! 通用解析器设计思路
//! 
//! 解析器通常分为两个阶段：
//! 1. 词法分析（Lexer/Tokenizer）：将输入字符串转换为 Token 流
//! 2. 语法分析（Parser）：将 Token 流转换为抽象语法树（AST）

const std = @import("std");

// ============================================
// 1. Token 定义（词法单元）
// ============================================
// 
// Token 是词法分析的最小单位，例如：
// - 关键字：if, else, while
// - 标识符：变量名、函数名
// - 字面量：数字、字符串
// - 运算符：+, -, *, /
// - 分隔符：{, }, (, ), ;

pub const TokenType = enum {
    // 字面量
    number,
    string,
    identifier,
    
    // 关键字
    kw_if,
    kw_else,
    kw_while,
    kw_return,
    
    // 运算符
    plus,      // +
    minus,     // -
    multiply,  // *
    divide,    // /
    assign,    // =
    equal,     // ==
    
    // 分隔符
    lparen,    // (
    rparen,    // )
    lbrace,    // {
    rbrace,    // }
    semicolon, // ;
    comma,     // ,
    
    // 特殊
    eof,       // 文件结束
    unknown,    // 未知字符
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,  // Token 的原始文本
    line: usize,        // 行号（用于错误报告）
    column: usize,      // 列号
};

// ============================================
// 2. Lexer（词法分析器）
// ============================================
// 
// 职责：
// - 读取输入字符串
// - 识别 Token
// - 返回 Token 流

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    line: usize = 1,
    column: usize = 1,
    
    pub fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .position = 0,
            .line = 1,
            .column = 1,
        };
    }
    
    // 获取下一个 Token
    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        
        if (self.isAtEnd()) {
            return self.makeToken(.eof, "");
        }
        
        const ch = self.currentChar();
        
        // 数字
        if (std.ascii.isDigit(ch)) {
            return self.readNumber();
        }
        
        // 标识符或关键字
        if (std.ascii.isAlphabetic(ch) or ch == '_') {
            return self.readIdentifier();
        }
        
        // 字符串
        if (ch == '"') {
            return self.readString();
        }
        
        // 单字符 Token
        return self.readSingleChar();
    }
    
    fn currentChar(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.input[self.position];
    }
    
    fn isAtEnd(self: *Lexer) bool {
        return self.position >= self.input.len;
    }
    
    fn advance(self: *Lexer) void {
        if (!self.isAtEnd()) {
            if (self.currentChar() == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
            self.position += 1;
        }
    }
    
    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd() and std.ascii.isWhitespace(self.currentChar())) {
            self.advance();
        }
    }
    
    fn readNumber(self: *Lexer) Token {
        const start = self.position;
        while (!self.isAtEnd() and std.ascii.isDigit(self.currentChar())) {
            self.advance();
        }
        const value = self.input[start..self.position];
        return self.makeToken(.number, value);
    }
    
    fn readIdentifier(self: *Lexer) Token {
        const start = self.position;
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.currentChar()) or self.currentChar() == '_')) {
            self.advance();
        }
        const value = self.input[start..self.position];
        
        // 检查是否是关键字
        const token_type = self.identifierType(value);
        return self.makeToken(token_type, value);
    }
    
    fn readString(self: *Lexer) Token {
        self.advance(); // 跳过开始的 "
        const start = self.position;
        while (!self.isAtEnd() and self.currentChar() != '"') {
            self.advance();
        }
        const value = self.input[start..self.position];
        self.advance(); // 跳过结束的 "
        return self.makeToken(.string, value);
    }
    
    fn readSingleChar(self: *Lexer) Token {
        const ch = self.currentChar();
        self.advance();
        
        const token_type = switch (ch) {
            '+' => .plus,
            '-' => .minus,
            '*' => .multiply,
            '/' => .divide,
            '=' => .assign,
            '(' => .lparen,
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            ';' => .semicolon,
            ',' => .comma,
            else => .unknown,
        };
        
        return self.makeToken(token_type, &[_]u8{ch});
    }
    
    fn identifierType(self: *Lexer, value: []const u8) TokenType {
        if (std.mem.eql(u8, value, "if")) return .kw_if;
        if (std.mem.eql(u8, value, "else")) return .kw_else;
        if (std.mem.eql(u8, value, "while")) return .kw_while;
        if (std.mem.eql(u8, value, "return")) return .kw_return;
        return .identifier;
    }
    
    fn makeToken(self: *Lexer, token_type: TokenType, value: []const u8) Token {
        return Token{
            .type = token_type,
            .value = value,
            .line = self.line,
            .column = self.column,
        };
    }
};

// ============================================
// 3. AST 节点定义（抽象语法树）
// ============================================
// 
// AST 表示程序的语法结构

pub const Expr = union(enum) {
    number: i32,
    string: []const u8,
    identifier: []const u8,
    binary: struct {
        left: *Expr,
        op: TokenType,
        right: *Expr,
    },
    call: struct {
        callee: []const u8,
        args: []Expr,
    },
};

pub const Stmt = union(enum) {
    expr: Expr,
    if_stmt: struct {
        condition: Expr,
        then_branch: *Stmt,
        else_branch: ?*Stmt,
    },
    while_stmt: struct {
        condition: Expr,
        body: *Stmt,
    },
    return_stmt: ?Expr,
};

pub const Program = struct {
    statements: []Stmt,
};

// ============================================
// 4. Parser（语法分析器）
// ============================================
// 
// 职责：
// - 读取 Token 流
// - 根据语法规则构建 AST
// - 处理语法错误

pub const Parser = struct {
    lexer: *Lexer,
    current: Token,
    peek: Token,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {
        var parser = Parser{
            .lexer = lexer,
            .current = undefined,
            .peek = undefined,
            .allocator = allocator,
        };
        parser.advance(); // 初始化 current 和 peek
        parser.advance();
        return parser;
    }
    
    fn advance(self: *Parser) void {
        self.current = self.peek;
        self.peek = self.lexer.nextToken();
    }
    
    // 解析程序（顶层）
    pub fn parse(self: *Parser) !Program {
        var statements = std.ArrayList(Stmt).init(self.allocator);
        defer statements.deinit();
        
        while (self.current.type != .eof) {
            try statements.append(try self.parseStatement());
        }
        
        return Program{
            .statements = try statements.toOwnedSlice(),
        };
    }
    
    fn parseStatement(self: *Parser) !Stmt {
        return switch (self.current.type) {
            .kw_if => try self.parseIfStatement(),
            .kw_while => try self.parseWhileStatement(),
            .kw_return => try self.parseReturnStatement(),
            else => Stmt{ .expr = try self.parseExpression() },
        };
    }
    
    fn parseIfStatement(self: *Parser) !Stmt {
        self.advance(); // 跳过 if
        const condition = try self.parseExpression();
        _ = try self.consume(.lbrace, "Expected '{' after if condition");
        const then_branch = try self.allocator.create(Stmt);
        then_branch.* = try self.parseStatement();
        _ = try self.consume(.rbrace, "Expected '}' after if body");
        
        var else_branch: ?*Stmt = null;
        if (self.current.type == .kw_else) {
            self.advance();
            _ = try self.consume(.lbrace, "Expected '{' after else");
            else_branch = try self.allocator.create(Stmt);
            else_branch.?.* = try self.parseStatement();
            _ = try self.consume(.rbrace, "Expected '}' after else body");
        }
        
        return Stmt{
            .if_stmt = .{
                .condition = condition,
                .then_branch = then_branch,
                .else_branch = else_branch,
            },
        };
    }
    
    fn parseWhileStatement(self: *Parser) !Stmt {
        self.advance(); // 跳过 while
        const condition = try self.parseExpression();
        _ = try self.consume(.lbrace, "Expected '{' after while condition");
        const body = try self.allocator.create(Stmt);
        body.* = try self.parseStatement();
        _ = try self.consume(.rbrace, "Expected '}' after while body");
        
        return Stmt{
            .while_stmt = .{
                .condition = condition,
                .body = body,
            },
        };
    }
    
    fn parseReturnStatement(self: *Parser) !Stmt {
        self.advance(); // 跳过 return
        var value: ?Expr = null;
        if (self.current.type != .semicolon) {
            value = try self.parseExpression();
        }
        _ = try self.consume(.semicolon, "Expected ';' after return");
        return Stmt{ .return_stmt = value };
    }
    
    fn parseExpression(self: *Parser) !Expr {
        return self.parseBinary(0); // 从最低优先级开始
    }
    
    // 递归下降解析（处理运算符优先级）
    fn parseBinary(self: *Parser, min_precedence: u8) !Expr {
        var left = try self.parseUnary();
        
        while (true) {
            const op = self.current.type;
            const precedence = self.getPrecedence(op);
            if (precedence < min_precedence) break;
            
            self.advance();
            const right = try self.parseBinary(precedence + 1);
            
            left = Expr{
                .binary = .{
                    .left = try self.allocator.create(Expr),
                    .op = op,
                    .right = try self.allocator.create(Expr),
                },
            };
            left.binary.left.* = left;
            left.binary.right.* = right;
        }
        
        return left;
    }
    
    fn parseUnary(self: *Parser) !Expr {
        if (self.current.type == .minus) {
            self.advance();
            const expr = try self.parseUnary();
            // 可以处理一元运算符
            return expr;
        }
        return self.parsePrimary();
    }
    
    fn parsePrimary(self: *Parser) !Expr {
        return switch (self.current.type) {
            .number => blk: {
                const value = try std.fmt.parseInt(i32, self.current.value, 10);
                self.advance();
                break :blk Expr{ .number = value };
            },
            .string => blk: {
                const value = self.current.value;
                self.advance();
                break :blk Expr{ .string = value };
            },
            .identifier => blk: {
                const value = self.current.value;
                self.advance();
                break :blk Expr{ .identifier = value };
            },
            .lparen => blk: {
                self.advance();
                const expr = try self.parseExpression();
                _ = try self.consume(.rparen, "Expected ')' after expression");
                break :blk expr;
            },
            else => error.UnexpectedToken,
        };
    }
    
    fn getPrecedence(self: *Parser, op: TokenType) u8 {
        _ = self;
        return switch (op) {
            .plus, .minus => 1,
            .multiply, .divide => 2,
            else => 0,
        };
    }
    
    fn consume(self: *Parser, expected: TokenType, message: []const u8) !Token {
        if (self.current.type == expected) {
            const token = self.current;
            self.advance();
            return token;
        }
        std.debug.print("Error at line {}: {s}\n", .{ self.current.line, message });
        return error.ParseError;
    }
};

// ============================================
// 5. 使用示例
// ============================================

pub fn example() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "if (x > 0) { return x + 1; }";
    
    // 1. 词法分析
    var lexer = Lexer.init(input);
    std.debug.print("=== Tokens ===\n", .{});
    while (true) {
        const token = lexer.nextToken();
        std.debug.print("Token: {s} ({s})\n", .{ @tagName(token.type), token.value });
        if (token.type == .eof) break;
    }
    
    // 2. 语法分析
    var lexer2 = Lexer.init(input);
    var parser = Parser.init(allocator, &lexer2);
    const program = try parser.parse();
    std.debug.print("\n=== Parsed AST ===\n", .{});
    std.debug.print("Program with {} statements\n", .{program.statements.len});
}

// ============================================
// 6. 设计要点总结
// ============================================
// 
// 1. 分离关注点：
//    - Lexer：只负责识别 Token
//    - Parser：只负责构建 AST
// 
// 2. 错误处理：
//    - 词法错误：无法识别的字符
//    - 语法错误：不符合语法规则
//    - 提供行号和列号信息
// 
// 3. 可扩展性：
//    - Token 类型可以轻松添加
//    - AST 节点类型可以扩展
//    - 支持不同的语法规则
// 
// 4. 性能考虑：
//    - 使用迭代器模式，不一次性加载所有 Token
//    - 延迟计算，按需解析
// 
// 5. 内存管理：
//    - 使用 allocator 管理 AST 节点
//    - 注意避免内存泄漏

