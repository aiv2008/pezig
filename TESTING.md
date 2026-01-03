# PEG 解析器测试指南

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
var parser = PEGParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("hello").?;
// rule.* == .literal
// rule.literal == "world"
```

### 2. 选择操作符

```zig
const grammar = "op = { \"+\" | \"-\" | \"*\" }";
var parser = PEGParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("op").?;
// rule.* == .choice
```

### 3. 序列操作符

```zig
const grammar = "ab = { \"a\" ~ \"b\" ~ \"c\" }";
var parser = PEGParser.init(allocator, grammar);
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

var parser = PEGParser.init(allocator, grammar);
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

var parser = PEGParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();
```

### 6. 规则引用

```zig
const grammar = 
    \\a = { "a" }
    \\b = { a }
;

var parser = PEGParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();

const rule = parser.rules.get("b").?;
// rule.* == .rule_ref
// rule.rule_ref == "a"
```

### 7. 括号表达式

```zig
const grammar = "expr = { ( \"a\" | \"b\" ) }";
var parser = PEGParser.init(allocator, grammar);
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

var parser = PEGParser.init(allocator, grammar);
try parser.parse();
defer parser.deinit();
```

## 在代码中使用

```zig
const std = @import("std");
const PEGParser = @import("ast.zig").PEGParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const grammar = "hello = { \"world\" }";
    
    var parser = PEGParser.init(allocator, grammar);
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

