# 实现文档

本文档记录当前实现进度、匹配引擎实现指南与测试指南。

---

## 当前实现进度

### 已实现功能（阶段 1.1 与 1.2 已完成）

- **阶段 1.1**：PEG 规则解析器（PEZParser、表达式解析、规则定义、内存管理）— 见下文 1–10。
- **阶段 1.2**：运行时匹配引擎（RuntimeParser、各 Rule 类型匹配、原子禁用回溯）— 见「阶段 1.2 已完成（匹配引擎）」小节。

#### 1. PEZParser 基础结构

已实现 `PEZParser` 结构体，包含：
- `input: []const u8` - 待解析的 PEG 语法字符串
- `position: usize` - 当前解析位置
- `rules: std.StringHashMap(*Rule)` - 存储解析出的规则（使用指针存储，便于内存管理）
- `allocator: std.mem.Allocator` - 内存分配器

```zig
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
pub fn parseIdentifier(self: *PEZParser) !?[]const u8 {
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
pub fn parseString(self: *PEZParser) !?[]const u8 {
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
pub fn parseRuleDefinition(self: *PEZParser) !struct { name: []const u8, rule: *Rule } {
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

- **`deinit()`** - 释放 PEZParser 及其所有规则
  - 遍历 HashMap 中的所有规则
  - 使用 `freeRule()` 递归释放
  - 释放 HashMap 本身

```zig
fn freeRule(self: *PEZParser, rule: *Rule) void {
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

pub fn deinit(self: *PEZParser) void {
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

#### 7. 表达式解析（✅ 已完成）

已实现完整的表达式解析功能链，按照 PEG 操作符优先级从低到高：

**完整的解析函数层次：**
1. **`parseExpression()`** - 处理选择操作符 `|`（最低优先级）
2. **`parseSequence()`** - 处理序列操作符 `~`
3. **`parsePostfix()`** - 处理后缀操作符 `?`, `+`, `*`
4. **`parsePrefix()`** - 处理前缀操作符 `!`, `&`, `_`, `@`
5. **`parsePrimary()`** - 处理基本元素（最高优先级）

- **`parsePrimary()`** - 解析原子表达式
  - ✅ 字符串字面量解析（`"hello"`），使用 `allocator.dupe()` 复制字符串
  - ✅ 规则引用解析（`term`），使用 `allocator.dupe()` 复制字符串
  - ✅ 括号表达式（`(expression)`），递归调用 `parseExpression()`

- **`parsePrefix()`** - 解析前缀操作符
  - ✅ 否定前瞻 `!`
  - ✅ 肯定前瞻 `&`
  - ✅ 静默 `_`
  - ✅ 原子 `@`
  - 前缀操作符是右结合的，例如 `!!a` 会被解析为 `!(!a)`

- **`parsePostfix()`** - 解析后缀操作符
  - ✅ 可选 `?` → `Rule.optional`
  - ✅ 一次或多次 `+` → `Rule.repeat{min=1, max=null}`
  - ✅ 零次或多次 `*` → `Rule.repeat{min=0, max=null}`
  - 支持多个后缀操作符链式使用，如 `"a"?+`

- **`parseSequence()`** - 解析序列操作符 `~`
  - ✅ 支持多个序列操作符连接，如 `A ~ B ~ C`
  - ✅ 正确构建左结合的序列结构

- **`parseExpression()`** - 解析选择操作符 `|`
  - ✅ 支持多个选择操作符连接，如 `A | B | C`
  - ✅ 正确构建左结合的选择结构

```zig
// 完整的解析函数调用链
fn parseExpression(self: *PEZParser) !*Rule {
    var left = try self.parseSequence();  // 调用 parseSequence
    
    while (true) {
        self.skipWhitespace();
        if (self.peek() != '|') break;
        _ = self.advance();
        const right = try self.parseSequence();
        
        const choice_ptr = try self.allocator.create(Rule);
        choice_ptr.* = Rule{ .choice = .{ .left = left, .right = right } };
        left = choice_ptr;
    }
    return left;
}

fn parseSequence(self: *PEZParser) !*Rule {
    var left = try self.parsePostfix();  // 调用 parsePostfix
    
    while (true) {
        self.skipWhitespace();
        if (self.peek() != '~') break;
        _ = self.advance();
        const right = try self.parsePostfix();
        
        const sequence_ptr = try self.allocator.create(Rule);
        sequence_ptr.* = Rule{ .sequence = .{ .left = left, .right = right } };
        left = sequence_ptr;
    }
    return left;
}

fn parsePostfix(self: *PEZParser) !*Rule {
    var left = try self.parsePrefix();  // 调用 parsePrefix
    
    while (true) {
        self.skipWhitespace();
        switch (self.peek() orelse break) {
            '?' => {
                _ = self.advance();
                const optional_ptr = try self.allocator.create(Rule);
                optional_ptr.* = Rule{ .optional = left };
                left = optional_ptr;
            },
            '+' => {
                _ = self.advance();
                const repeat_ptr = try self.allocator.create(Rule);
                repeat_ptr.* = Rule{ .repeat = .{ .rule = left, .min = 1, .max = null } };
                left = repeat_ptr;
            },
            '*' => {
                _ = self.advance();
                const repeat_ptr = try self.allocator.create(Rule);
                repeat_ptr.* = Rule{ .repeat = .{ .rule = left, .min = 0, .max = null } };
                left = repeat_ptr;
            },
            else => break,
        }
    }
    return left;
}

fn parsePrefix(self: *PEZParser) !*Rule {
    self.skipWhitespace();
    const ch = self.peek() orelse return ast_errors.AstError.NotAnAst;
    
    switch (ch) {
        '!', '&', '_', '@' => {
            _ = self.advance();
            const inner = try self.parsePrefix();  // 递归调用
            const rule_ptr = try self.allocator.create(Rule);
            rule_ptr.* = switch (ch) {
                '!' => Rule{ .not_predicate = inner },
                '&' => Rule{ .and_predicate = inner },
                '_' => Rule{ .silent = inner },
                '@' => Rule{ .atomic = inner },
                else => unreachable,
            };
            return rule_ptr;
        },
        else => return try self.parsePrimary(),  // 调用 parsePrimary
    }
}

fn parsePrimary(self: *PEZParser) !*Rule {
    // 解析字符串字面量、括号表达式、规则引用
    // 使用 allocator.dupe() 复制字符串
}
```

#### 8. 规则定义解析（✅ 已完成）

- **`parseRuleDefinition()`** - 解析完整的规则定义
  - ✅ 解析规则名并复制字符串
  - ✅ 识别 `=` 和 `{}` 语法
  - ✅ 使用 `parseExpression()` 解析规则体
  - ✅ 返回规则名和规则指针

```zig
pub fn parseRuleDefinition(self: *PEZParser) !struct { name: []const u8, rule: *Rule } {
    const name_slice = try self.parseIdentifier();
    const name = try self.allocator.dupe(u8, name_slice);  // 复制规则名
    
    // 跳过 '=' 和 '{'
    // ...
    
    const rule_ptr = try self.parseExpression();  // 解析规则体
    
    // 跳过 '}'
    // ...
    
    return .{ .name = name, .rule = rule_ptr };
}
```

#### 9. 主解析函数（✅ 已完成）

- **`parse()`** - 解析整个 PEG 语法定义
  - ✅ 循环解析多个规则定义
  - ✅ 将所有规则存储到 HashMap 中
  - ✅ 处理空白字符和规则分隔

```zig
pub fn parse(self: *PEZParser) !void {
    while (!self.isAtEnd()) {
        self.skipWhitespace();
        if (self.isAtEnd()) break;
        
        const rule_def = try self.parseRuleDefinition();
        try self.rules.put(rule_def.name, rule_def.rule);
        
        self.skipWhitespace();
    }
}
```

#### 10. 内存管理完善（✅ 已完成）

- **更新 `deinit()`** - 释放所有资源
  - ✅ 释放所有规则名字符串（HashMap 的 key）
  - ✅ 释放所有规则对象及其嵌套规则
  - ✅ 释放 HashMap 本身

```zig
pub fn deinit(self: *PEZParser) void {
    var it = self.rules.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);  // 释放规则名
        self.freeRule(entry.value_ptr.*);      // 释放规则对象
    }
    self.rules.deinit();
}
```

### 阶段 1.1 完成总结

**✅ 已完成的功能：**
- PEG 规则解析器完整实现
- 所有 PEG 操作符支持（`~`, `|`, `?`, `+`, `*`, `!`, `&`, `_`, `@`）
- 完整的操作符优先级处理
- 括号表达式支持
- 规则定义解析
- 主解析函数
- 完整的内存管理

**测试示例：**

```zig
const gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

const grammar = 
    \\expression = { term ~ ("+" | "-") ~ term }
    \\term = { factor ~ ("*" | "/") ~ factor }
    \\factor = { number | "(" ~ expression ~ ")" }
    \\number = { ASCII_DIGIT+ }
;

var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

// 检查解析结果
const expr_rule = parser.rules.get("expression");
// expr_rule 现在包含完整的规则 AST
```

### 阶段 1.2 已完成（匹配引擎）

**✅ 已实现：**

1. **基础匹配引擎**
   - `RuntimeParser` 结构体，基于 `PEZParser` 的规则 HashMap
   - `match(rule_name, input)`：按规则名匹配输入，返回 `*MatchResult`
   - `MatchResult` 含 `success`、`start_position`、`end_position`、`matched_text`、`children`、`atomic_failure`

2. **规则类型匹配（均已接入 `matchResult` 的 switch）**
   - ✅ 字面量匹配（`Rule.literal`）— `matchLiteral`
   - ✅ 规则引用（`Rule.rule_ref`）— `matchRuleRef`
   - ✅ 序列（`Rule.sequence`）— `matchSequence`
   - ✅ 选择（`Rule.choice`）— `matchChoice`
   - ✅ 可选（`Rule.optional`）— `matchOptional`
   - ✅ 重复（`Rule.repeat`）— `matchRepeat`
   - ✅ 否定前瞻（`Rule.not_predicate`，`!A`）— `matchNotPredicate`，不消费输入
   - ✅ 肯定前瞻（`Rule.and_predicate`，`&A`）— `matchAndPredicate`，不消费输入
   - ✅ 静默（`Rule.silent`，`_A`）— `matchSilent`，匹配但不捕获（消费输入、不暴露子结果）
   - ✅ 原子（`Rule.atomic`，`@A`）— `matchAtomic`，失败时设置 `atomic_failure`，`matchChoice` 在原子失败时不再试右分支（禁用回溯）
   - ✅ 正则（`Rule.regex`）— `matchRegex`，基于 zig-regex 在 `input[pos..]` 上匹配，且**只接受从 pos 开头开始的匹配**（见下）

3. **内存与错误路径**
   - 所有 match 分支的 `errdefer` 与成功/失败路径的 `deinit`/`destroy` 已处理，避免泄漏与 use-after-free

**⏳ 尚未实现（仍走 `matchResult` 的 `else` 返回失败）：**
   - `Rule.precedence` — 需 `matchPrecedence` 按优先级层级尝试

#### matchRegex：为何要检查「匹配从开头开始」

`matchRegex` 在实现时会对 `regex.find(suffix)` 的结果做一次判断：`if (m.slice.ptr != suffix.ptr) { ... return 失败 }`。这样做的原因和示例如下。

**这段代码在做什么**

- `suffix = input[pos..]`：从位置 `pos` 开始到结尾的那一段输入。
- `regex.find(suffix)`：在**整段** `suffix` 里找**第一个**能匹配上的子串。
- `m.slice`：这次匹配到的子串（在 `suffix` 里的某一段）。
- `m.slice.ptr != suffix.ptr`：匹配到的子串**不是**从 `suffix` 的**第一个字符**开始的。

含义：**只有在「从 pos 开头」就匹配上时我们才接受，否则当成匹配失败。**

**为什么要这样做（PEG 语义）**

在 PEG 里，一条规则在位置 `pos` 的匹配含义是：**只关心「从 pos 开始能不能匹配」**，不关心「在 pos 后面的某个位置能不能匹配」。若 `find` 在 `suffix` 中间某处才匹配到，那**不算**「在 pos 处匹配成功」，应返回失败。只有匹配到的 `m.slice` 正好就是 `suffix` 的前缀（即 `m.slice.ptr == suffix.ptr`）时，才表示「在 pos 处匹配成功」。因此需要这段判断：**`m.slice.ptr != suffix.ptr` 就返回失败。**

**举例**

| 例子 | input / pos / reg | suffix | find 结果 | m.slice.ptr == suffix.ptr? | 是否接受 |
|------|-------------------|--------|-----------|----------------------------|----------|
| 从开头匹配（成功） | `input = "123"`, `pos = 0`, `reg = "\\d+"` | `"123"` | 匹配 `"123"` | 是 | ✅ 成功 |
| 匹配在中间（失败） | `input = "x123"`, `pos = 0`, `reg = "\\d+"` | `"x123"` | 在中间匹配到 `"123"` | 否（ptr 指向不同） | ❌ 失败 |
| 从 pos>0 匹配（成功） | `input = "x123"`, `pos = 1`, `reg = "\\d+"` | `"123"` | 匹配 `"123"` | 是 | ✅ 成功 |

**小结**

- 目的：实现 PEG 的「在 pos 处匹配」——只接受从 `input[pos]` 就开始的匹配。
- 做法：在 `input[pos..]` 上做 `find`，并检查匹配是否从这段的**开头**开始（`m.slice.ptr == suffix.ptr`）。
- 否则（`m.slice.ptr != suffix.ptr`）返回失败，避免把「在中间某处才匹配到」误当成「在 pos 匹配成功」。

### 下一步待实现

1. **可选：匹配引擎扩展**
   - 实现 `matchPrecedence`，支持优先级组规则（`matchRegex` 已实现，见上）

2. **可选：回溯机制**
   - 若需“可回溯的 repeat”（少匹配几次再试），在 repeat 内需根据 `atomic_failure` 决定是否尝试更少次数

3. **错误与可观测性**（✅ 已完成）
   - 匹配失败时返回更详细的错误信息（位置、期望规则等）
   - 已实现：`errors.byteIndexToLineColumn`、`errors.formatFailureMessage`；失败用例测试（字面量失败、repeat 不足 min、辅助函数）

## 匹配失败的错误信息语义

### MatchResult 的失败约定

- **success**:
  - `true`: 规则在当前位置匹配成功。
  - `false`: 规则在当前位置匹配失败（语义失败，而不是系统错误）。
- **start_position / end_position**:
  - 成功时：`[start_position, end_position)` 是本次匹配消耗的输入区间，单位是 **byte index**。
  - 失败时：`start_position == end_position == pos`，其中 `pos` 是「尝试匹配该规则时的起始位置」，即**失败位置**。
- **expected_rule_name**:
  - 在失败时，用作**人类可读的“期望描述”**，例如期望的字面量或正则模式：
    - 字面量失败时为对应的 `literal`。
    - 正则失败时为对应的 `reg`。
  - 若当前规则没有一个简单的“单一期望”（例如组合规则、前瞻等），可以为 `null`。

### ParserError 与 MatchResult 的分工

- `ParserError`（见 `errors.zig`）只用于：
  - **结构性/系统性错误**：如规则未找到 (`RuleNotFound`)、语法未闭合、内存分配失败等。
- `MatchResult` 用于描述**语义匹配结果**：
  - 成功：`success == true`，并附带子节点等信息。
  - 失败：`success == false`，位置在 `start_position`，期望在 `expected_rule_name`。

调用栈的约定是：

- `RuntimeParser.match()` 返回：
  - `error ParserError`: 表示解析过程中出现结构/系统错误。
  - `*MatchResult`: 表示语义匹配结束（成功或失败），此时应根据 `success` 字段判断是否匹配成功。
- 上层代码在需要向用户/测试暴露错误时：
  - 使用 `MatchResult.start_position` 作为**失败 byte index**。
  - 可选：根据完整输入将该 byte index 转换为「行号/列号」。
  - 使用 `expected_rule_name` 构造「在位置 X 期望 ……」之类的错误文案。

### 可选后续：byte index → 行/列

- 若需对用户展示「第几行第几列」：
  - 输入：完整 `input: []const u8` 与失败位置 `pos: usize`（即 byte index）。
  - 逻辑：遍历 `input[0..pos]` 统计 `\n` 得到行号；列号 = `pos - 当前行起始 index`（可从 1 或 0 开始，与项目约定一致）。
  - 建议：在需要打印错误时再调用，不改变 MatchResult 结构；可提供辅助函数如 `byteIndexToLineColumn(input, index) -> { line, column }`。

### 可选后续：失败用例测试清单

- 字面量失败：规则 `hello = { "world" }`，输入 `"hello"` → 断言 `!result.success`、`start_position == 0`、`expected_rule_name` 含 `"world"`。
- repeat 不足 min：规则 `"a"+`（min=2），输入 `"a"` → 断言失败位置为 `current_pos`（例如 1）。
- 前瞻、原子失败：!A / &A / @A 失败时 `start_position == 原 pos`，原子失败时 `atomic_failure == true`。

---

## 下一步：matchPrecedence（匹配引擎扩展）

当前 `matchResult` 的 `else` 分支对 `Rule.precedence` 返回失败。下一步为实现 `matchPrecedence`，使优先级组规则可参与匹配。

### 数据结构（当前 ast.zig）

- `Precedence`：`rules: []Rule`，`levels: []PrecedenceLevel`。
- `PrecedenceLevel`：`level: u8`，`associativity: enum { left, right, none }`，`rule: *Rule`。

### 实现要点（引导，不写具体代码）

1. **在 matchResult 中接入**  
   对 `rule.* == .precedence` 不再走 `else`，改为调用新函数，例如 `matchPrecedence(rule.precedence, input, pos)`，返回 `!*MatchResult`。

2. **matchPrecedence 的语义**  
   - 按**优先级层级**依次尝试：通常按 `levels` 顺序（或按 `level` 字段排序后）从低到高尝试，直到某一层在 `pos` 处匹配成功。
   - 每一层用该层对应的 `PrecedenceLevel.rule` 在当前位置调用 `matchResult`；若成功则返回该结果（并可记录匹配到的层级）；若失败则尝试下一层。
   - 若所有层都失败，返回一个失败 `MatchResult`，位置为 `pos`，`expected_rule_name` 可为 `null` 或汇总「期望某一层级」的描述。

3. **结合性（associativity）**  
   - 若语法/规则已在 PEZ 解析阶段展开为左结合/右结合序列，则运行时可能只需按层尝试即可。
   - 若需在匹配阶段体现结合性，左结合可在同一层内循环「匹配 op 再匹配下一级」；右结合可递归「匹配下一级再匹配 op」。先实现「按层尝试」即可，结合性可后续再细化。

4. **内存与错误**  
   - 成功时返回该层 `matchResult` 的结果，由调用方统一释放。
   - 失败时新建一个 `MatchResult`（如 `matchFailInit`），保证与其它分支一致，避免泄漏。

5. **测试**  
   - 若已有或后续添加带 `precedence` 的语法（如 DESIGN 中的 `expression = precedence!{ ... }`），用简单表达式（如 `1+2*3`）验证先匹配低优先级层、再匹配高优先级层，且结果与预期一致。

---


## 二、PEG 匹配引擎实现指南（原 MATCH_ENGINE_GUIDE.md）


## 当前状态

✅ **已完成**：阶段1.1 - PEG规则解析器（PEZParser）
- 可以解析PEG语法规则
- 构建了完整的Rule AST
- 所有操作符都支持

⏳ **待实现**：阶段1.2 - 匹配引擎（RuntimeParser）
- 需要根据Rule AST匹配输入字符串

---

## 实现目标

实现一个运行时解析器，能够：
1. 接受已解析的PEG规则（Rule AST）
2. 对输入字符串执行匹配
3. 返回匹配结果（MatchResult）

---

## 实现步骤（分步引导）

### 步骤1：理解匹配引擎的核心概念

#### 1.1 什么是匹配引擎？

匹配引擎的作用是：
- 输入：PEG规则（Rule AST） + 输入字符串
- 处理：根据规则在输入字符串中查找匹配
- 输出：匹配结果（成功/失败、匹配位置、匹配文本等）

#### 1.2 PEG匹配的特点

**有序选择（Ordered Choice）**：
- `A | B` 表示：先尝试A，如果成功就返回；如果失败，再尝试B
- 这与正则表达式不同（正则使用"最长匹配"）

**回溯（Backtracking）**：
- 如果某个选择失败，需要回溯到之前的位置
- 例如：`"a" ~ ("b" | "c")` 匹配 "ac"：
  1. 先匹配 "a" ✅
  2. 尝试匹配 "b" ❌
  3. 回溯，尝试匹配 "c" ✅

#### 1.3 匹配结果（MatchResult）

查看 `src/ast.zig` 中的 `MatchResult` 定义：
- `success: bool` - 是否匹配成功
- `start_position: usize` - 匹配开始位置
- `end_position: usize` - 匹配结束位置
- `matched_text: []const u8` - 匹配的文本
- `children: std.ArrayList(*MatchResult)` - 子匹配结果（用于嵌套规则）

**思考题**：
- 为什么需要 `children`？什么时候会有子匹配结果？
- `end_position` 和 `matched_text` 的关系是什么？

---

### 步骤2：设计 RuntimeParser 的结构

#### 2.1 当前代码状态

查看 `src/parser.zig` 中的 `RuntimeParser`：
```zig
pub const RuntimeParser = struct {
    rules: std.StringHashMap(*Rule),
    allocator: std.mem.Allocator,
    // ...
};
```

**问题**：
1. `rules` 存储了什么？
2. 为什么需要 `allocator`？
3. 还需要其他字段吗？

#### 2.2 思考：还需要什么字段？

可能的额外字段（根据你的实现方式选择）：
- **匹配状态**：当前匹配位置、回溯栈等
- **错误信息**：匹配失败时的详细错误

**建议**：
- 先实现基础版本，不需要额外字段
- 匹配状态可以作为函数参数传递
- 错误信息可以先简单处理

**任务**：检查 `RuntimeParser.init()` 的实现是否正确

---

### 步骤3：实现主匹配方法 `match()`

#### 3.1 方法签名

```zig
pub fn match(
    self: *RuntimeParser,
    rule_name: []const u8,  // 要匹配的规则名
    input: []const u8,       // 输入字符串
) !*MatchResult
```

#### 3.2 实现思路

1. **查找规则**：根据 `rule_name` 从 `rules` HashMap 中获取规则
   - 如果没有找到，返回错误
   
2. **初始化匹配**：从位置0开始匹配
   - 调用 `matchRule()` 方法（下一步实现）
   
3. **创建 MatchResult**：
   - 如果匹配成功：创建成功的 MatchResult
   - 如果匹配失败：创建失败的 MatchResult

#### 3.3 关键问题

- 如果规则引用不存在怎么办？
- 匹配应该从字符串的哪个位置开始？
- 是否需要完全匹配整个字符串，还是部分匹配即可？

**任务**：实现 `match()` 方法的基础框架

---

### 步骤4：实现核心匹配方法 `matchRule()`

#### 4.1 方法签名

```zig
fn matchRule(
    self: *RuntimeParser,
    rule: *Rule,           // 要匹配的规则
    input: []const u8,     // 输入字符串
    pos: usize,            // 当前匹配位置
) !?*MatchResult          // 返回null表示匹配失败
```

**注意**：返回 `?*MatchResult` 表示可能匹配失败（返回null）

#### 4.2 实现思路：使用 switch 处理所有 Rule 类型

```zig
switch (rule.*) {
    .literal => {
        // 处理字面量匹配
    },
    .rule_ref => {
        // 处理规则引用
    },
    .sequence => {
        // 处理序列（A ~ B）
    },
    .choice => {
        // 处理选择（A | B）
    },
    // ... 其他类型
    else => {
        // 暂未实现
    },
}
```

#### 4.3 关键问题

- 如何判断是否超出字符串范围？
- 匹配失败时应该返回什么？
- 如何分配 MatchResult 内存？

**任务**：实现 `matchRule()` 的框架（先处理几个简单的类型）

---

### 步骤5：实现字面量匹配 `matchLiteral()`

#### 5.1 思路

字面量匹配最简单：
- 检查从 `pos` 位置开始，输入字符串是否以字面量开头
- 如果匹配，创建 MatchResult
- 如果不匹配，返回 null

#### 5.2 实现要点

1. **边界检查**：
   - `pos + literal.len > input.len` → 匹配失败

2. **字符串比较**：
   - 使用 `std.mem.eql()` 或 `std.mem.startsWith()`
   - 比较 `input[pos..pos + literal.len]` 和 `literal`

3. **创建结果**：
   - 成功：创建 MatchResult，设置 `start_position = pos`，`end_position = pos + literal.len`
   - 失败：返回 null

#### 5.3 示例

匹配规则：`hello = { "world" }`
- 输入：`"world123"` → 匹配成功，位置 0-5
- 输入：`"hello world"` → 匹配失败

**任务**：在 `matchRule()` 中实现 `.literal` 分支

---

### 步骤6：实现规则引用匹配 `matchRuleRef()`

#### 6.1 思路

规则引用就是递归调用：
- 根据规则名从 `rules` 中查找规则
- 递归调用 `matchRule()` 匹配该规则
- 返回匹配结果

#### 6.2 实现要点

1. **查找规则**：
   - 从 `self.rules` 中查找 `rule_ref` 对应的规则
   - 如果找不到，返回错误（规则引用未定义）

2. **递归调用**：
   - 调用 `self.matchRule(found_rule, input, pos)`
   - 这是递归的起点

#### 6.3 关键问题

- **循环引用**：如果规则A引用规则B，规则B又引用规则A怎么办？
  - 先不考虑，基础版本可能遇到无限递归
  - 高级版本可以用记忆化（memoization）解决

**任务**：在 `matchRule()` 中实现 `.rule_ref` 分支

---

### 步骤7：实现序列匹配 `matchSequence()`

#### 7.1 思路

序列 `A ~ B` 表示：先匹配A，再匹配B
- 在位置 `pos` 匹配A
- 如果A匹配成功，在A的结束位置匹配B
- 如果A或B匹配失败，整个序列失败

#### 7.2 实现步骤

1. **匹配左侧规则（A）**：
   ```zig
   const left_result = try self.matchRule(sequence.left, input, pos);
   if (left_result == null) {
       return null; // 左侧匹配失败
   }
   ```

2. **匹配右侧规则（B）**：
   ```zig
   const right_result = try self.matchRule(
       sequence.right, 
       input, 
       left_result.?.end_position  // 从A的结束位置开始
   );
   if (right_result == null) {
       // 释放 left_result 的内存
       return null; // 右侧匹配失败
   }
   ```

3. **创建序列结果**：
   - 新的 `start_position = left_result.start_position`
   - 新的 `end_position = right_result.end_position`
   - 将 `left_result` 和 `right_result` 添加到 `children`

#### 7.3 关键问题

- 如果左侧匹配成功但右侧失败，是否需要回溯？
  - 在PEG中，序列是"必须全部成功"，所以不需要额外回溯
- 如何管理子结果的内存？
  - 需要将 `left_result` 和 `right_result` 添加到父结果的 `children`

**任务**：实现 `.sequence` 分支

---

### 步骤8：实现选择匹配 `matchChoice()`

#### 8.1 思路（关键：有序选择）

选择 `A | B` 表示：先尝试A，如果A成功就返回；如果A失败，再尝试B
- **有序选择**：这是PEG的核心特性
- 不需要同时尝试A和B，按顺序尝试即可

#### 8.2 实现步骤

1. **先尝试左侧（A）**：
   ```zig
   const left_result = try self.matchRule(choice.left, input, pos);
   if (left_result) |result| {
       // A匹配成功，直接返回
       return result;
   }
   ```

2. **如果A失败，尝试右侧（B）**：
   ```zig
   // A失败了，尝试B（从相同位置开始）
   return try self.matchRule(choice.right, input, pos);
   ```

#### 8.3 关键点

- **回溯是自动的**：如果A失败，位置自动回到 `pos`，然后尝试B
- **不需要显式回溯**：因为匹配失败时位置指针不会移动

**任务**：实现 `.choice` 分支

---

### 步骤9：实现可选匹配 `matchOptional()`

#### 9.1 思路

可选 `A?` 表示：尝试匹配A，如果成功返回结果；如果失败，返回"匹配成功但匹配了0个字符"
- 可选永远不会失败，最多匹配0个字符

#### 9.2 实现步骤

1. **尝试匹配内部规则**：
   ```zig
   const result = try self.matchRule(optional.rule, input, pos);
   ```

2. **如果匹配成功**：
   - 返回结果（直接返回 `result`）

3. **如果匹配失败**：
   - 创建一个"空匹配"的 MatchResult
   - `start_position = pos`
   - `end_position = pos`（没有匹配任何字符）
   - `success = true`（注意：仍然是成功的！）

#### 9.3 关键点

- 可选操作符**永远不会失败**
- 如果内部规则匹配失败，返回的是"空匹配"，不是失败

**任务**：实现 `.optional` 分支

---

### 步骤10：实现重复匹配 `matchRepeat()`

#### 10.1 思路

重复 `A+` 或 `A*`：
- `A+`：匹配1次或多次
- `A*`：匹配0次或多次
- 使用循环，每次尝试匹配A，直到失败

#### 10.2 实现步骤

1. **初始化**：
   - 记录开始位置 `start_pos = pos`
   - 当前匹配位置 `current_pos = pos`
   - 匹配次数 `count = 0`
   - 子结果列表

2. **循环匹配**：
   ```zig
   while (true) {
       const result = try self.matchRule(repeat.rule, input, current_pos);
       if (result) |r| {
           // 匹配成功
           count += 1;
           current_pos = r.end_position;
           // 将结果添加到子结果列表
           if (count == repeat.max) break; // 达到最大次数
       } else {
           // 匹配失败，退出循环
           break;
       }
   }
   ```

3. **检查最小次数**：
   - 如果 `count < repeat.min`，返回 null（匹配失败）
   - 否则创建结果

#### 10.3 关键点

- 需要检查 `min` 和 `max` 限制
- 将所有子匹配结果保存到 `children`
- 如果 `max` 是 `null`，表示无上限

**任务**：实现 `.repeat` 分支

---

### 步骤11：实现前缀操作符（可选，稍后实现）

#### 11.1 否定前瞻 `!A`

- 匹配逻辑：尝试匹配A，如果A**失败**，则匹配成功（但不消耗输入）
- 关键：不移动位置指针，只检查是否能匹配

#### 11.2 肯定前瞻 `&A`

- 匹配逻辑：尝试匹配A，如果A**成功**，则匹配成功（但不消耗输入）
- 关键：不移动位置指针

#### 11.3 静默 `_A`

- 匹配逻辑：匹配A，但不捕获结果（不添加到children）

#### 11.4 原子 `@A`

- 匹配逻辑：匹配A，如果失败，不回溯（高级特性，可以先跳过）

**任务**：先跳过，完成基础功能后再回来实现

---

### 步骤12：测试和调试

#### 12.1 简单测试用例

1. **字面量匹配**：
   ```
   规则: hello = { "world" }
   输入: "world" → 应该成功
   输入: "hello" → 应该失败
   ```

2. **序列匹配**：
   ```
   规则: ab = { "a" ~ "b" }
   输入: "ab" → 应该成功
   输入: "ac" → 应该失败
   ```

3. **选择匹配**：
   ```
   规则: op = { "a" | "b" }
   输入: "a" → 应该成功（匹配左侧）
   输入: "b" → 应该成功（匹配右侧）
   输入: "c" → 应该失败
   ```

#### 12.2 调试技巧

- 添加调试输出：打印匹配位置、匹配的规则类型
- 检查内存泄漏：确保所有分配的 MatchResult 都被正确释放
- 验证边界情况：空字符串、单个字符、超长字符串

**任务**：编写测试用例，验证每个功能

---

## 实现顺序建议

### 第一阶段：基础匹配（核心功能）

1. ✅ 实现 `match()` 方法框架
2. ✅ 实现 `matchRule()` 框架（switch语句）
3. ✅ 实现字面量匹配（`.literal`）
4. ✅ 实现规则引用匹配（`.rule_ref`）
5. ✅ 实现序列匹配（`.sequence`）
6. ✅ 实现选择匹配（`.choice`）

**目标**：能够匹配简单的PEG规则

### 第二阶段：扩展功能

7. ✅ 实现可选匹配（`.optional`）
8. ✅ 实现重复匹配（`.repeat`）

**目标**：支持所有基础操作符

### 第三阶段：高级功能（可选）

9. ⏳ 实现前缀操作符（`!`, `&`, `_`, `@`）
10. ⏳ 实现回溯优化
11. ⏳ 实现记忆化（memoization）

---

## 常见问题和陷阱

### 1. 内存管理

- **问题**：MatchResult 需要动态分配内存
- **解决**：使用 `allocator.create(MatchResult)` 创建
- **注意**：需要记得释放内存，避免泄漏

### 2. 字符串切片

- **问题**：`matched_text` 应该是输入字符串的切片
- **解决**：使用 `input[start..end]` 创建切片
- **注意**：确保 `start` 和 `end` 不越界

### 3. 递归深度

- **问题**：规则引用可能导致无限递归
- **解决**：先实现基础版本，遇到问题再优化
- **注意**：测试时要避免循环引用

### 4. 空匹配

- **问题**：可选操作符可能返回空匹配
- **解决**：确保空匹配的 `start_position == end_position`
- **注意**：空匹配仍然是"成功"的

---

## 学习检查点

完成每一步后，问自己：

1. ✅ 我理解这个步骤的目标吗？
2. ✅ 我理解实现思路吗？
3. ✅ 我理解可能的问题和陷阱吗？
4. ✅ 我能编写测试用例验证功能吗？

---

## 下一步行动

1. **从步骤1开始**：理解匹配引擎的核心概念
2. **逐步实现**：按照顺序，一步一步实现
3. **及时测试**：每完成一个功能，立即测试
4. **遇到问题**：查阅文档、调试代码、思考问题

**记住**：不要急于求成，理解每一行代码的作用，这样学到的知识才能真正掌握！

祝你实现顺利！🎉

---

## 三、PEG 解析器测试指南（原 TESTING.md）


## 运行测试

### 方式 1: 使用 Zig 内置测试

运行所有测试：

```bash
zig build test
```

这会运行：
- `src/ast.zig` 中的所有 `test` 块
- `src/root.zig` 中的所有 `test` 块
- `src/main.zig` 中的所有 `test` 块

### 方式 2: 运行示例程序

```bash
zig build run
```

这会运行 `src/main.zig` 中的 `main()` 函数，展示 PEG 解析器的使用示例。

### 方式 3: 运行单个模块的测试

```bash
# 测试 ast.zig
zig test src/ast.zig -I src

# 测试 main.zig
zig test src/main.zig -I src
```

## 测试用例

### 1. 简单字面量规则

```zig
const grammar = "hello = { \"world\" }";
var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("hello").?;
// rule.* == .literal
// rule.literal == "world"
```

### 2. 选择操作符

```zig
const grammar = "op = { \"+\" | \"-\" | \"*\" }";
var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("op").?;
// rule.* == .choice
```

### 3. 序列操作符

```zig
const grammar = "ab = { \"a\" ~ \"b\" ~ \"c\" }";
var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("ab").?;
// rule.* == .sequence
```

### 4. 后缀操作符

```zig
const grammar = 
    \\opt = { "a"? }
    \\plus = { "b"+ }
    \\star = { "c"* }
;

var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

// opt: Rule.optional
// plus: Rule.repeat{min=1, max=null}
// star: Rule.repeat{min=0, max=null}
```

### 5. 前缀操作符

```zig
const grammar = 
    \\not = { !"a" }
    \\and = { &"a" }
    \\silent = { _"a" }
    \\atomic = { @"a" }
;

var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();
```

### 6. 规则引用

```zig
const grammar = 
    \\a = { "a" }
    \\b = { a }
;

var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("b").?;
// rule.* == .rule_ref
// rule.rule_ref == "a"
```

### 7. 括号表达式

```zig
const grammar = "expr = { ( \"a\" | \"b\" ) }";
var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();
```

### 8. 复杂表达式

```zig
const grammar = 
    \\expression = { term ~ ("+" | "-") ~ term }
    \\term = { factor ~ ("*" | "/") ~ factor }
    \\factor = { number | "(" ~ expression ~ ")" }
    \\number = { ASCII_DIGIT+ }
;

var parser = PEZParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();
```

## 在代码中使用

```zig
const std = @import("std");
const PEZParser = @import("ast.zig").PEZParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const grammar = "hello = { \"world\" }";
    
    var parser = PEZParser.init(allocator, grammar);
    try parser.parse();
    defer parser.deinit();  // 自动释放所有内存
    
    // 检查规则
    if (parser.rules.get("hello")) |rule| {
        std.debug.print("规则类型: {}\n", .{rule.*});
        if (rule.* == .literal) {
            std.debug.print("字面量: {s}\n", .{rule.literal});
        }
    }
}
```

## 注意事项

1. **内存管理**: 始终使用 `defer parser.deinit()` 来释放内存
2. **错误处理**: 所有解析函数都可能返回错误，需要使用 `try` 或 `catch`
3. **规则名**: 规则名必须唯一，后定义的规则会覆盖先定义的规则（在 HashMap 中）

## 调试技巧

1. **打印解析结果**:
   ```zig
   var it = parser.rules.iterator();
   while (it.next()) |entry| {
       std.debug.print("规则: {s}\n", .{entry.key_ptr.*});
   }
   ```

2. **检查规则类型**:
   ```zig
   switch (rule.*) {
       .literal => std.debug.print("字面量: {s}\n", .{rule.literal}),
       .choice => std.debug.print("选择操作符\n", .{}),
       .sequence => std.debug.print("序列操作符\n", .{}),
       // ...
   }
   ```

3. **使用 Zig 的调试工具**:
   ```bash
   # 详细编译错误信息
   zig build run --verbose

   # 查看生成的汇编代码
   zig build -femit-asm
   ```

