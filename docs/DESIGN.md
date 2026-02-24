# 设计文档

本文档描述 pezig 的架构与设计思路（核心思想、组件、关键特性与实现步骤规划）。实现进度与操作指南见 [IMPLEMENTATION.md](IMPLEMENTATION.md)。

---

## 一、设计思路（原 README 主体）

### 核心思想

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
pub const PEZParser = struct {
    input: []const u8,
    position: usize = 0,
    rules: std.StringHashMap(Rule),
    allocator: std.mem.Allocator,
    
    // 解析 PEG 语法定义
    pub fn parse(self: *PEZParser) !void {
        // 1. 解析规则定义
        // 2. 识别操作符
        // 3. 构建规则树
        // 4. 验证规则引用
    }
    
    // 解析单个规则
    fn parseRule(self: *PEZParser) !Rule {
        // 解析规则名称
        // 解析规则体
        // 处理操作符优先级
    }
    
    // 解析表达式（处理优先级）
    fn parseExpression(self: *PEZParser) !Rule {
        // 处理选择运算符 |
    }
    
    // 解析序列（处理 ~ 运算符）
    fn parseSequence(self: *PEZParser) !Rule {
        // 处理序列运算符 ~
    }
    
    // 解析前缀操作符
    fn parsePrefix(self: *PEZParser) !Rule {
        // 处理 !, &, _, @
    }
    
    // 解析后缀操作符
    fn parsePostfix(self: *PEZParser) !Rule {
        // 处理 ?, +, *
    }
};
```

#### 操作符优先级处理机制

在 PEG 解析器中，操作符优先级通过**递归下降解析器的函数调用层次**来实现。核心思想是：**优先级低的操作符在外层函数处理，优先级高的操作符在内层函数处理**。

##### PEG 操作符优先级（从低到高）

1. **选择** `|` - 最低优先级
2. **序列** `~` - 中间优先级  
3. **前缀** `!`, `&`, `_`, `@` - 较高优先级
4. **后缀** `?`, `+`, `*` - 更高优先级
5. **基本元素** - 最高优先级（字面量、规则引用、括号）

##### 函数调用层次

```
parseExpression    ← 最外层，处理 | (优先级最低)
  ↓ 调用
parseSequence      ← 处理 ~
  ↓ 调用
parsePrefix        ← 处理 !, &, _, @
  ↓ 调用
parsePostfix       ← 处理 ?, +, *
  ↓ 调用
parsePrimary       ← 最内层，处理基本元素 (优先级最高)
```

##### 解析过程示例

**例子 1：解析 `"a" ~ "b" | "c"`**

```
输入: "a" ~ "b" | "c"
```

1. **`parseExpression`**（处理 `|`）：
   - 调用 `parseSequence()` 解析 `"a" ~ "b"`（在遇到 `|` 之前）
   - 遇到 `|`，再调用 `parseSequence()` 解析 `"c"`
   - 构建 `choice`：`("a" ~ "b") | "c"`

2. **`parseSequence`**（处理 `~`）：
   - 调用 `parsePrimary()` 解析 `"a"`
   - 遇到 `~`
   - 再调用 `parsePrimary()` 解析 `"b"`
   - 构建 `sequence`：`"a" ~ "b"`

3. **`parsePrimary`**（处理基本元素）：
   - 识别 `"a"` 为字面量
   - 返回 `Rule{ .literal = "a" }`

**最终 AST 结构：**
```
choice
├─ sequence
│  ├─ literal: "a"
│  └─ literal: "b"
└─ literal: "c"
```

**例子 2：解析 `"a" | "b" ~ "c"`**

```
输入: "a" | "b" ~ "c"
```

由于 `|` 在外层处理，会先被识别：

1. **`parseExpression`** 先遇到 `"a"`，调用 `parseSequence()`
2. **`parseSequence`** 解析 `"a"`（单个元素，没有 `~`）
3. **`parseExpression`** 遇到 `|`，继续解析右边
4. **`parseExpression`** 调用 `parseSequence()` 解析 `"b" ~ "c"`
5. 构建 `choice`：`"a" | ("b" ~ "c")`

**结果**：`"a" | ("b" ~ "c")`，而不是 `("a" | "b") ~ "c"` ✅

##### 关键理解点

1. **优先级低的先处理**：
   - `parseExpression` 处理 `|`，所以它先尝试解析整个序列，然后才处理 `|`

2. **左结合性**：
   ```zig
   var left = try self.parseSequence();  // 先解析左边
   const right = try self.parseSequence(); // 再解析右边
   left = choice_ptr;  // 新的 left 包含了之前的 left 和 right
   ```
   这样构建的是左结合：`a | b | c` = `((a | b) | c)`

3. **为什么这样能保证优先级？**
   
   `parseSequence` 只解析到基本元素级别就停止，不会解析 `|`（因为 `|` 的检查在外层 `parseExpression`）：
   
   ```zig
   // parseExpression (外层)
   var left = try self.parseSequence();  // 调用 parseSequence，不会解析到 | 就停止
   if (peek() == '|') {                 // 这里才检查 |
       const right = try self.parseSequence();
   }
   
   // parseSequence (内层)
   var left = try self.parsePrimary();   // 只解析到基本元素
   if (peek() == '~') {                 // 只检查 ~，不检查 |
       const right = try self.parsePrimary();
   }
   ```

##### 总结

- **函数调用层次 = 优先级**：外层函数处理低优先级操作符，内层函数处理高优先级操作符
- **每个函数只处理自己的操作符**：其他操作符交给外层或内层函数处理
- **解析顺序**：从最高优先级开始，逐步向外层构建 AST

这就是为什么 `parseExpression` 调用 `parseSequence`，而 `parseSequence` 调用 `parsePrimary` 的原因。

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


---

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
