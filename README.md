# Zig 实现类似 Pest 的通用解析器设计思路

## 概述

本文档描述如何在 Zig 中实现一个类似 Rust [Pest](https://pest.rs/) 的基于 PEG（Parsing Expression Grammar）的通用解析器。

## 核心思想

### PEG vs 传统解析器

**传统递归下降解析器：**
- 语法规则硬编码在代码中
- 需要手动处理优先级和结合性
- 左递归需要转换

**PEG 解析器（类似 Pest）：**
- 声明式语法定义
- 自动处理优先级
- 天然支持左递归
- 更好的错误恢复

## 架构设计

### 三层架构

```
语法规则定义（PEG 字符串）
    ↓
[PEG 规则解析器] 解析语法定义
    ↓
规则对象（Rule AST）
    ↓
[解析器生成器/运行时解析器]
    ↓
生成的解析器代码 / 运行时解析器
```

### 数据流

```
输入字符串
    ↓
[生成的解析器] 根据规则匹配
    ↓
匹配结果 / AST
```

## 核心组件

### 1. PEG 规则定义

#### 语法示例

```peg
expression = { term ~ ("+" | "-") ~ term }
term = { factor ~ ("*" | "/") ~ factor }
factor = { number | "(" ~ expression ~ ")" }
number = { ASCII_DIGIT+ }
```

#### PEG 操作符

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `~` | 序列（连接） | `A ~ B` |
| `\|` | 选择（有序） | `A \| B` |
| `?` | 可选 | `A?` |
| `+` | 一次或多次 | `A+` |
| `*` | 零次或多次 | `A*` |
| `!` | 否定前瞻 | `!A` |
| `&` | 肯定前瞻 | `&A` |
| `_` | 静默（不捕获） | `_A` |
| `@` | 原子 | `@A` |

### 2. 规则对象（Rule AST）

```zig
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
```

### 3. PEG 规则解析器

#### 职责

- 解析 PEG 语法字符串
- 识别规则定义和操作符
- 构建规则 AST
- 验证规则有效性

#### 实现要点

```zig
pub const PEGParser = struct {
    input: []const u8,
    position: usize = 0,
    rules: std.StringHashMap(Rule),
    allocator: std.mem.Allocator,
    
    // 解析 PEG 语法定义
    pub fn parse(self: *PEGParser) !void {
        // 1. 解析规则定义
        // 2. 识别操作符
        // 3. 构建规则树
        // 4. 验证规则引用
    }
    
    // 解析单个规则
    fn parseRule(self: *PEGParser) !Rule {
        // 解析规则名称
        // 解析规则体
        // 处理操作符优先级
    }
    
    // 解析表达式（处理优先级）
    fn parseExpression(self: *PEGParser) !Rule {
        // 处理选择运算符 |
    }
    
    // 解析序列（处理 ~ 运算符）
    fn parseSequence(self: *PEGParser) !Rule {
        // 处理序列运算符 ~
    }
    
    // 解析前缀操作符
    fn parsePrefix(self: *PEGParser) !Rule {
        // 处理 !, &, _, @
    }
    
    // 解析后缀操作符
    fn parsePostfix(self: *PEGParser) !Rule {
        // 处理 ?, +, *
    }
};
```

### 4. 解析器生成器

#### 方式 1：编译时代码生成（推荐）

**思路：**
- 使用 Zig 的 `comptime` 特性
- 在编译时解析 PEG 规则
- 生成解析器代码
- 零运行时开销

**实现：**

```zig
// 使用 comptime 函数生成解析器
pub fn generateParser(comptime grammar: []const u8) type {
    comptime {
        // 1. 解析 PEG 规则
        const rules = parsePEGRules(grammar);
        
        // 2. 生成解析器结构体
        return struct {
            // 生成的解析方法
            pub fn parse(input: []const u8) !AST {
                // 生成的解析逻辑
            }
        };
    }
}

// 使用示例
const MyParser = generateParser(
    \\expression = { term ~ ("+" | "-") ~ term }
    \\term = { factor ~ ("*" | "/") ~ factor }
);
```

#### 方式 2：运行时解析器

**思路：**
- 运行时解析 PEG 规则
- 构建规则树
- 根据规则树匹配输入
- 更灵活，但性能稍差

**实现：**

```zig
pub const RuntimeParser = struct {
    rules: std.StringHashMap(Rule),
    allocator: std.mem.Allocator,
    
    // 根据规则匹配输入
    pub fn match(self: *RuntimeParser, rule_name: []const u8, input: []const u8) !MatchResult {
        const rule = self.rules.get(rule_name) orelse return error.RuleNotFound;
        return self.matchRule(rule, input, 0);
    }
    
    // 递归匹配规则
    fn matchRule(self: *RuntimeParser, rule: Rule, input: []const u8, pos: usize) !MatchResult {
        return switch (rule) {
            .literal => self.matchLiteral(rule.literal, input, pos),
            .sequence => self.matchSequence(rule.sequence, input, pos),
            .choice => self.matchChoice(rule.choice, input, pos),
            // ... 其他规则类型
        };
    }
};
```

### 5. 匹配引擎

#### 回溯机制

**核心思想：**
- PEG 使用有序选择（ordered choice）
- 第一个匹配成功就返回
- 需要保存匹配状态，支持回溯

**实现：**

```zig
pub const MatchState = struct {
    input: []const u8,
    position: usize,
    stack: std.ArrayList(BacktrackPoint),
    
    // 保存回溯点
    fn savePoint(self: *MatchState) !void {
        try self.stack.append(.{
            .position = self.position,
        });
    }
    
    // 回溯到上一个点
    fn backtrack(self: *MatchState) void {
        if (self.stack.popOrNull()) |point| {
            self.position = point.position;
        }
    }
    
    // 提交（清除回溯点）
    fn commit(self: *MatchState) void {
        _ = self.stack.pop();
    }
};
```

#### 记忆化（Memoization）

**思路：**
- 缓存规则匹配结果
- 避免重复计算
- 提高性能（Packrat Parsing）

**实现：**

```zig
pub const MemoTable = struct {
    entries: std.HashMap(MemoKey, MemoEntry),
    
    pub const MemoKey = struct {
        rule_id: usize,
        position: usize,
    };
    
    pub const MemoEntry = struct {
        result: ?MatchResult,
        end_position: usize,
    };
    
    // 查找缓存
    fn lookup(self: *MemoTable, key: MemoKey) ?MemoEntry {
        return self.entries.get(key);
    }
    
    // 存储结果
    fn store(self: *MemoTable, key: MemoKey, entry: MemoEntry) !void {
        try self.entries.put(key, entry);
    }
};
```

## 关键特性实现

### 1. 优先级和结合性

#### 语法定义

```peg
expression = precedence!{
    x: { term ~ ("+" | "-") ~ x } ~ ADD_SUB,
    x: { term ~ ("*" | "/") ~ x } ~ MUL_DIV,
    x: { "(" ~ x ~ ")" | number } ~ ATOM,
}
```

#### 实现思路

1. **解析优先级定义**：识别 `precedence!` 块
2. **展开规则**：将优先级规则展开为普通规则
3. **生成解析代码**：根据优先级生成匹配逻辑

```zig
pub const PrecedenceLevel = struct {
    level: u8,
    associativity: enum { left, right, none },
    rule: Rule,
};

fn expandPrecedence(rule: Rule) []Rule {
    // 将优先级规则展开为多个规则
    // 每个优先级级别对应一个规则
}
```

### 2. 左递归处理

#### PEG 天然支持左递归

**思路：**
- 使用增长检测（growing detection）
- 检测到左递归时，使用迭代而非递归
- 或转换为右递归

**实现：**

```zig
fn matchLeftRecursive(
    self: *Parser,
    rule: Rule,
    input: []const u8,
    pos: usize,
) !MatchResult {
    var last_result: ?MatchResult = null;
    var current_pos = pos;
    
    // 增长检测：如果匹配位置没有增长，停止
    while (true) {
        const result = try self.matchRule(rule, input, current_pos);
        if (result.end_position <= current_pos) {
            // 没有增长，返回上次结果
            return last_result orelse result;
        }
        last_result = result;
        current_pos = result.end_position;
    }
}
```

### 3. 错误恢复

#### 思路

- 使用 `recover_with` 规则
- 定义错误恢复点
- 尝试多个规则，选择最佳匹配

```zig
pub const ErrorRecovery = struct {
    recovery_points: []RecoveryPoint,
    
    pub const RecoveryPoint = struct {
        rule: Rule,
        skip_until: []const u8,  // 跳过直到匹配
    };
    
    fn recover(self: *ErrorRecovery, error: ParseError) !void {
        // 尝试从恢复点继续解析
    }
};
```

### 4. 语义动作

#### 思路

- 规则匹配后执行回调函数
- 构建 AST 或执行其他操作
- 支持自定义处理逻辑

```zig
pub const SemanticAction = struct {
    rule_name: []const u8,
    callback: fn (match: MatchResult, context: *Context) anyerror!void,
};

// 在规则匹配成功后调用
fn executeAction(action: SemanticAction, match: MatchResult) !void {
    try action.callback(match, &context);
}
```

## 实现步骤

### 阶段 1：基础 PEG 解析器

1. **实现 PEG 规则解析器**
   - 解析规则定义
   - 识别基本操作符（~, |, ?, +, *）
   - 构建简单规则树

2. **实现基础匹配引擎**
   - 字面量匹配
   - 序列匹配
   - 选择匹配

### 阶段 2：高级特性

3. **添加优先级支持**
   - 解析优先级定义
   - 实现优先级展开

4. **实现左递归**
   - 增长检测
   - 迭代匹配

5. **添加记忆化**
   - 实现缓存表
   - 优化性能

### 阶段 3：代码生成

6. **实现编译时代码生成**
   - 使用 `comptime` 解析规则
   - 生成解析器代码
   - 优化生成的代码

7. **添加错误处理**
   - 错误恢复机制
   - 详细的错误信息

## 当前实现进度

### 已实现功能（阶段 1.1 部分完成）

#### 1. PEGParser 基础结构

已实现 `PEGParser` 结构体，包含：
- `input: []const u8` - 待解析的 PEG 语法字符串
- `position: usize` - 当前解析位置
- `rules: std.StringHashMap(*Rule)` - 存储解析出的规则（使用指针存储，便于内存管理）
- `allocator: std.mem.Allocator` - 内存分配器

```zig
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
};
```

#### 2. 基础辅助函数

实现了以下辅助函数，用于解析过程中的字符处理：

- **`skipWhitespace()`** - 跳过空白字符（空格、制表符、换行符）
- **`isAtEnd()`** - 检查是否到达输入末尾
- **`peek()`** - 获取当前字符（不移动位置指针）
- **`advance()`** - 读取当前字符并移动位置指针

#### 3. 标识符解析

实现了 `parseIdentifier()` 函数，用于解析规则名：
- 支持字母、数字、下划线
- 必须以字母或下划线开头
- 返回解析出的标识符字符串切片

```zig
pub fn parseIdentifier(self: *PEGParser) !?[]const u8 {
    self.skipWhitespace();
    if (self.isAtEnd()) return null;
    
    const first_char = self.input[self.position];
    if (!std.ascii.isAlphabetic(first_char) and first_char != '_') {
        return null;
    }
    
    const start_pos = self.position;
    self.position += 1;
    
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
```

#### 4. 字符串字面量解析

实现了 `parseString()` 函数，用于解析 PEG 语法中的字符串字面量：
- 支持双引号包围的字符串
- 返回引号内的内容（不包括引号本身）
- 包含错误处理（未闭合字符串检测）

```zig
pub fn parseString(self: *PEGParser) !?[]const u8 {
    self.skipWhitespace();
    if (self.isAtEnd()) return null;
    
    if (self.input[self.position] != '"') {
        return null;
    }
    
    self.position += 1;
    const start_pos = self.position;
    
    while (!self.isAtEnd()) {
        if (self.peek() == '"') {
            break;
        }
        self.position += 1;
    }
    
    if (self.isAtEnd()) {
        return error.UnterminatedString;
    }
    
    const end_pos = self.position;
    self.position += 1; // 跳过结束引号
    
    return self.input[start_pos..end_pos];
}
```

#### 5. 规则定义解析（基础版本）

实现了 `parseRuleDefinition()` 函数，用于解析完整的规则定义：
- 解析规则名
- 识别 `=` 和 `{}` 语法
- 目前返回占位规则（规则体解析待实现）

```zig
pub fn parseRuleDefinition(self: *PEGParser) !struct { name: []const u8, rule: *Rule } {
    self.skipWhitespace();
    const ident_opt = try self.parseIdentifier();
    const name = ident_opt orelse return ast_errors.AstError.NotAnAst;
    
    // 跳过 '='
    self.skipWhitespace();
    if (self.peek() != '=') return ast_errors.AstError.NotAnAst;
    _ = self.advance();
    
    // 跳过 '{'
    self.skipWhitespace();
    if (self.peek() != '{') return ast_errors.AstError.NotAnAst;
    _ = self.advance();
    
    // TODO: 解析规则体（下一步实现）
    const rule_ptr = try self.allocator.create(Rule);
    rule_ptr.* = Rule{ .literal = "TODO" };
    
    // 跳过 '}'
    self.skipWhitespace();
    if (self.peek() != '}') return ast_errors.AstError.NotAnAst;
    _ = self.advance();
    
    return .{
        .name = name,
        .rule = rule_ptr,
    };
}
```

#### 6. 内存管理

实现了完整的内存管理机制：

- **`freeRule()`** - 递归释放单个 Rule 及其所有嵌套规则
  - 处理所有包含指针的 Rule 类型（sequence, choice, optional, repeat 等）
  - 正确处理嵌套结构的释放

- **`deinit()`** - 释放 PEGParser 及其所有规则
  - 遍历 HashMap 中的所有规则
  - 使用 `freeRule()` 递归释放
  - 释放 HashMap 本身

```zig
fn freeRule(self: *PEGParser, rule: *Rule) void {
    switch (rule.*) {
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
        // ... 其他类型的处理
        else => {
            self.allocator.destroy(rule);
        },
    }
}

pub fn deinit(self: *PEGParser) void {
    var it = self.rules.iterator();
    while (it.next()) |entry| {
        self.freeRule(entry.value_ptr.*);
    }
    self.rules.deinit();
}
```

### 设计决策

1. **HashMap 存储指针而非值**：`std.StringHashMap(*Rule)` 而不是 `std.StringHashMap(Rule)`
   - 优点：更高效（避免大结构体复制）、便于共享规则、递归释放简单
   - 缺点：需要手动管理内存

2. **递归内存释放**：所有包含指针的 Rule 类型都通过 `freeRule()` 递归释放
   - 确保没有内存泄漏
   - 正确处理嵌套结构

#### 7. 表达式解析（部分完成）

已实现基础的表达式解析功能：

- **`parsePrimary()`** - 解析原子表达式
  - ✅ 字符串字面量解析（`"hello"`）
  - ✅ 规则引用解析（`term`）
  - ⏳ 括号表达式（`(expression)`）待实现

- **`parseExpression()`** - 解析表达式，处理选择操作符
  - ✅ 选择操作符 `|` 的处理
  - ⏳ 序列操作符 `~` 待实现（需要 parseSequence）

```zig
// parsePrimary - 解析原子表达式
fn parsePrimary(self: *PEGParser) !*Rule {
    // 解析字符串字面量
    if (self.peek() == '"') {
        const str_opt = try self.parseString();
        const str = str_opt orelse return ast_errors.AstError.Unterminated;
        const rule_ptr = try self.allocator.create(Rule);
        rule_ptr.* = Rule{ .literal = str };
        return rule_ptr;
    }
    
    // 解析括号表达式（待实现）
    // ...
    
    // 解析规则引用
    const ident_opt = try self.parseIdentifier();
    if (ident_opt) |name| {
        const rule_ptr = try self.allocator.create(Rule);
        rule_ptr.* = Rule{ .rule_ref = name };
        return rule_ptr;
    }
    
    return ast_errors.AstError.NotAnAst;
}

// parseExpression - 处理选择操作符 |
fn parseExpression(self: *PEGParser) !*Rule {
    var left = try self.parsePrimary();
    
    while (true) {
        self.skipWhitespace();
        if (self.peek() != '|') break;
        _ = self.advance(); // 跳过 '|'
        
        const right = try self.parsePrimary();
        
        const choice_ptr = try self.allocator.create(Rule);
        choice_ptr.* = Rule{ .choice = .{
            .left = left,
            .right = right,
        } };
        
        left = choice_ptr;
    }
    
    return left;
}
```

### 下一步待实现

1. **修复字符串内存管理问题**
   - ⚠️ **重要**：当前 `parsePrimary()` 中，字符串字面量和规则引用没有复制字符串
   - 需要使用 `allocator.dupe()` 复制字符串，否则会出现生命周期问题

2. **实现序列操作符解析**
   - 实现 `parseSequence()` 函数，处理序列操作符 `~`
   - 更新 `parseExpression()` 调用 `parseSequence()` 而不是 `parsePrimary()`

3. **完成括号表达式解析**
   - 在 `parsePrimary()` 中实现括号表达式处理
   - 递归调用 `parseExpression()` 解析括号内的表达式

4. **完善规则定义解析**
   - 更新 `parseRuleDefinition()` 使用 `parseExpression()` 替换占位规则
   - 确保规则体正确解析

5. **实现后缀和前缀操作符**
   - 解析后缀操作符（`?`, `+`, `*`）
   - 解析前缀操作符（`!`, `&`, `_`, `@`）

6. **主解析函数**
   - 实现 `parse()` 方法，解析整个 PEG 语法定义
   - 将所有规则存储到 HashMap 中

## Zig 实现优势

### 1. 编译时计算

```zig
// 在编译时解析规则并生成解析器
const Parser = comptime generateParser(grammar);
```

### 2. 零成本抽象

- 生成的代码性能等同于手写代码
- 没有运行时开销

### 3. 类型安全

- 编译时验证规则有效性
- 检查规则引用
- 类型安全的 AST

### 4. 内存安全

- 使用 allocator 管理内存
- 避免内存泄漏
- 明确的资源管理

## 简化版设计

如果不想实现完整的 PEG 引擎，可以：

1. **简化语法**：只支持核心操作符（~, |, ?, +, *）
2. **固定优先级**：预定义优先级规则
3. **代码生成**：生成简单的递归下降解析器
4. **逐步扩展**：先实现基础功能，再添加高级特性

## 与 Pest 的对比

| 特性 | Pest (Rust) | Zig 实现 |
|------|------------|----------|
| 语法定义 | 声明式 | 声明式 |
| 代码生成 | 编译时宏 | comptime |
| 性能 | 优秀 | 优秀（零成本） |
| 类型安全 | 是 | 是 |
| 错误信息 | 详细 | 可自定义 |
| 左递归 | 支持 | 支持 |
| 记忆化 | 支持 | 可实现 |

## 总结

### 核心思路

1. **声明式语法**：用规则定义语法，而不是代码
2. **规则解析**：先解析规则本身，再生成解析器
3. **回溯匹配**：实现 PEG 的匹配机制
4. **代码生成或运行时**：选择性能或灵活性

### 设计优势

- **易用性**：语法定义清晰直观
- **可维护性**：修改语法只需改规则
- **可扩展性**：易于添加新特性
- **类型安全**：编译时验证规则
- **高性能**：编译时代码生成，零运行时开销

### 适用场景

- 配置文件解析
- 领域特定语言（DSL）
- 数据格式解析（JSON, XML 等）
- 代码分析工具
- 模板引擎

## 参考资源

- [PEG 语法规范](https://en.wikipedia.org/wiki/Parsing_expression_grammar)
- [Pest 文档](https://pest.rs/)
- [Packrat Parsing](https://en.wikipedia.org/wiki/Packrat_parsing)
- [Zig comptime 文档](https://ziglang.org/documentation/#comptime)

