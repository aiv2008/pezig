# PEG 匹配引擎实现指南

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
