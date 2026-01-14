# EVM（以太坊虚拟机）开发计划

## 项目概述

本项目旨在使用 Zig 语言实现一个完整的 EVM（Ethereum Virtual Machine）虚拟机，支持以太坊智能合约的执行。

## 开发目标

- ✅ 实现完整的 EVM 指令集（256 个操作码）
- ✅ 实现执行环境（栈、内存、存储）
- ✅ 实现 Gas 计算机制
- ✅ 支持合约调用和消息调用
- ✅ 支持 EIP-1559 等以太坊协议特性
- ✅ 良好的性能和安全性

## 开发阶段划分

### 阶段 0：需求分析与设计（1-2 周）

#### 任务清单
- [ ] 研究 EVM 规范和 Yellow Paper
- [ ] 确定实现范围和优先级
- [ ] 设计整体架构
- [ ] 确定数据结构设计
- [ ] 制定测试策略

#### 核心文档阅读
- [ ] Ethereum Yellow Paper（黄皮书）
- [ ] EVM 操作码规范
- [ ] EIP 相关文档（EIP-1559, EIP-2930 等）
- [ ] 现有 EVM 实现参考（go-ethereum, py-evm）

#### 设计决策
- [ ] 选择支持的以太坊版本（Frontier, Homestead, Tangerine Whistle, Spurious Dragon, Byzantium, Constantinople, Istanbul, Berlin, London 等）
- [ ] 内存管理策略（堆分配 vs 栈分配）
- [ ] Gas 计算的实现方式
- [ ] 错误处理机制

---

### 阶段 1：基础数据结构（1 周）

#### 1.1 基本类型定义
- [ ] `U256` - 256 位无符号整数（以太坊的基本数据类型）
- [ ] `Address` - 20 字节地址类型
- [ ] `Hash` - 32 字节哈希类型
- [ ] `Gas` - Gas 数量类型

#### 1.2 执行环境（Execution Context）
- [ ] `ExecutionContext` - 执行上下文
  - [ ] `code: []const u8` - 合约字节码
  - [ ] `data: []const u8` - 调用数据
  - [ ] `gas: Gas` - 剩余 Gas
  - [ ] `caller: Address` - 调用者地址
  - [ ] `callee: Address` - 被调用者地址
  - [ ] `value: U256` - 转账金额

#### 1.3 执行状态（Execution State）
- [ ] `Stack` - 执行栈（最多 1024 个 U256）
  - [ ] `push(value: U256) !void`
  - [ ] `pop() !U256`
  - [ ] `peek(depth: usize) !U256`
- [ ] `Memory` - 执行内存（动态扩展）
  - [ ] `store(offset: usize, value: U256) !void`
  - [ ] `load(offset: usize) !U256`
- [ ] `Storage` - 持久化存储（账户状态）
  - [ ] `sstore(key: U256, value: U256) !void`
  - [ ] `sload(key: U256) !U256`

#### 1.4 账户状态
- [ ] `Account` - 账户结构
  - [ ] `balance: U256` - 余额
  - [ ] `nonce: u64` - 交易计数
  - [ ] `code_hash: Hash` - 代码哈希
  - [ ] `storage: HashMap(U256, U256)` - 存储

---

### 阶段 2：字节码解析与指令集（2 周）

#### 2.1 字节码解析
- [ ] `BytecodeParser` - 字节码解析器
  - [ ] 解析操作码（Opcode）
  - [ ] 解析立即数（Push 指令的数据）
  - [ ] 验证字节码有效性

#### 2.2 操作码定义
- [ ] 定义所有 256 个操作码的枚举
- [ ] 操作码分类：
  - [ ] 算术运算（ADD, MUL, SUB, DIV, MOD, etc.）
  - [ ] 位运算（AND, OR, XOR, NOT, SHL, SHR, etc.）
  - [ ] 比较运算（LT, GT, EQ, ISZERO, etc.）
  - [ ] 栈操作（PUSH1-PUSH32, POP, DUP1-DUP16, SWAP1-SWAP16, etc.）
  - [ ] 内存操作（MLOAD, MSTORE, MSTORE8, MSIZE）
  - [ ] 存储操作（SLOAD, SSTORE）
  - [ ] 控制流（JUMP, JUMPI, JUMPDEST, PC, etc.）
  - [ ] 调用操作（CALL, CALLCODE, DELEGATECALL, STATICCALL, CREATE, CREATE2, etc.）
  - [ ] 日志操作（LOG0-LOG4）
  - [ ] 系统操作（RETURN, REVERT, SELFDESTRUCT, etc.）
  - [ ] 其他（STOP, INVALID, etc.）

#### 2.3 指令执行框架
- [ ] `execute(opcode: Opcode, ctx: *ExecutionContext) !ExecutionResult`
- [ ] 为每个操作码实现执行逻辑（可以先实现基础指令）

---

### 阶段 3：基础指令实现（2-3 周）

#### 3.1 栈操作指令（优先级：最高）
- [ ] `PUSH1` - `PUSH32`（推送 1-32 字节数据到栈）
- [ ] `POP`（弹出栈顶元素）
- [ ] `DUP1` - `DUP16`（复制栈中第 N 个元素到栈顶）
- [ ] `SWAP1` - `SWAP16`（交换栈顶和第 N 个元素）

#### 3.2 算术指令
- [ ] `ADD`（加法）
- [ ] `MUL`（乘法）
- [ ] `SUB`（减法）
- [ ] `DIV`（除法）
- [ ] `SDIV`（有符号除法）
- [ ] `MOD`（取模）
- [ ] `SMOD`（有符号取模）
- [ ] `ADDMOD`（模加）
- [ ] `MULMOD`（模乘）
- [ ] `EXP`（指数运算）

#### 3.3 比较和位运算
- [ ] `LT`（小于）
- [ ] `GT`（大于）
- [ ] `SLT`（有符号小于）
- [ ] `SGT`（有符号大于）
- [ ] `EQ`（等于）
- [ ] `ISZERO`（是否为零）
- [ ] `AND`（按位与）
- [ ] `OR`（按位或）
- [ ] `XOR`（按位异或）
- [ ] `NOT`（按位非）
- [ ] `BYTE`（提取字节）
- [ ] `SHL`（左移）
- [ ] `SHR`（右移）
- [ ] `SAR`（算术右移）

#### 3.4 内存操作
- [ ] `MLOAD`（从内存加载）
- [ ] `MSTORE`（存储到内存）
- [ ] `MSTORE8`（存储字节到内存）
- [ ] `MSIZE`（获取内存大小）

---

### 阶段 4：Gas 计算（1-2 周）

#### 4.1 Gas 计算框架
- [ ] `GasCalculator` - Gas 计算器
- [ ] 实现基础 Gas 成本常量
- [ ] 实现动态 Gas 计算（内存扩展、存储操作等）

#### 4.2 各类指令的 Gas 成本
- [ ] 零 Gas 指令（STOP, RETURN, etc.）
- [ ] 基础 Gas 指令（ADD, MUL, etc.）
- [ ] 内存扩展 Gas（MLOAD, MSTORE, etc.）
- [ ] 存储操作 Gas（SLOAD, SSTORE）
- [ ] 调用操作 Gas（CALL, CREATE, etc.）

#### 4.3 Gas 限制检查
- [ ] 在执行每条指令前检查剩余 Gas
- [ ] 实现 Gas 不足时的回滚机制

---

### 阶段 5：控制流与调用（2-3 周）

#### 5.1 控制流指令
- [ ] `JUMP`（无条件跳转）
- [ ] `JUMPI`（条件跳转）
- [ ] `JUMPDEST`（跳转目标标记）
- [ ] `PC`（程序计数器）
- [ ] `STOP`（停止执行）

#### 5.2 调用机制
- [ ] `CALL`（普通调用）
  - [ ] 创建新的执行上下文
  - [ ] 处理 Gas 传递
  - [ ] 处理返回值
- [ ] `CALLCODE`（代码调用）
- [ ] `DELEGATECALL`（委托调用）
- [ ] `STATICCALL`（静态调用）
- [ ] `RETURN`（返回数据）
- [ ] `REVERT`（回滚）

#### 5.3 合约创建
- [ ] `CREATE`（创建合约）
  - [ ] 计算新合约地址
  - [ ] 执行初始化代码
  - [ ] 部署合约代码
- [ ] `CREATE2`（确定性合约创建）

---

### 阶段 6：存储与日志（1 周）

#### 6.1 存储操作
- [ ] `SLOAD`（从存储加载）
- [ ] `SSTORE`（存储到存储）
  - [ ] 实现 Gas 退款机制
  - [ ] 处理存储的冷/热访问

#### 6.2 日志操作
- [ ] `LOG0` - `LOG4`（日志记录）
  - [ ] 处理日志主题（topics）
  - [ ] 处理日志数据（data）

---

### 阶段 7：系统指令与优化（1-2 周）

#### 7.1 系统指令
- [ ] `SELFDESTRUCT`（自毁）
- [ ] `INVALID`（无效指令）
- [ ] 环境指令（ADDRESS, BALANCE, ORIGIN, CALLER, CALLVALUE, etc.）
- [ ] 区块信息指令（NUMBER, TIMESTAMP, GASLIMIT, etc.）
- [ ] 合约信息指令（CODESIZE, CODECOPY, etc.）

#### 7.2 性能优化
- [ ] 指令执行性能分析
- [ ] 内存分配优化
- [ ] Gas 计算优化
- [ ] 代码缓存机制

---

### 阶段 8：测试与验证（2-3 周）

#### 8.1 单元测试
- [ ] 为每个指令编写单元测试
- [ ] 测试边界情况
- [ ] 测试错误处理

#### 8.2 集成测试
- [ ] 使用以太坊官方测试套件
- [ ] 测试完整的合约执行流程
- [ ] 测试 Gas 计算准确性

#### 8.3 兼容性测试
- [ ] 与现有 EVM 实现对比测试
- [ ] 执行真实合约进行验证
- [ ] 性能基准测试

---

### 阶段 9：文档与发布（1 周）

#### 9.1 文档编写
- [ ] API 文档
- [ ] 使用示例
- [ ] 架构说明
- [ ] 开发指南

#### 9.2 发布准备
- [ ] 代码审查
- [ ] 性能测试报告
- [ ] 发布说明

---

## 技术要点

### 数据结构选择

1. **U256 实现**
   - 使用 `[4]u64` 或 `[32]u8` 表示
   - 实现大整数运算（加法、乘法、除法等）

2. **栈实现**
   - 使用固定大小数组 `[1024]U256`
   - 栈指针管理

3. **内存实现**
   - 使用动态数组 `std.ArrayList(u8)`
   - 实现内存扩展逻辑

4. **存储实现**
   - 使用 HashMap 存储键值对
   - 支持持久化到数据库（可选）

### 关键设计决策

1. **执行模式**
   - 顺序执行 vs 解释执行
   - JIT 编译（可选，高级特性）

2. **错误处理**
   - 使用 Zig 的错误处理机制
   - 区分可恢复错误和不可恢复错误

3. **Gas 计算**
   - 内联计算 vs 独立模块
   - Gas 预检查 vs 后检查

---

## 参考资料

### 官方文档
- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [EVM Opcodes](https://ethereum.org/en/developers/docs/evm/opcodes/)
- [Ethereum Improvement Proposals (EIPs)](https://eips.ethereum.org/)

### 参考实现
- [go-ethereum (Geth)](https://github.com/ethereum/go-ethereum)
- [py-evm](https://github.com/ethereum/py-evm)
- [SputnikVM](https://github.com/rust-blockchain/evm)
- [revm (Rust EVM)](https://github.com/bluealloy/revm)

### 测试资源
- [Ethereum Tests](https://github.com/ethereum/tests)
- [EVM Test Cases](https://github.com/ethereum/tests/tree/develop/GeneralStateTests)

---

## 开发建议

### 开发顺序建议
1. **先实现基础指令**：从栈操作、算术指令开始，这些指令逻辑简单，容易测试
2. **逐步扩展**：每实现一批指令，就编写测试验证
3. **先实现核心功能**：控制流和调用机制是核心，需要仔细设计
4. **最后优化**：在功能完整后再考虑性能优化

### 测试策略
- **单元测试优先**：每个指令独立测试
- **使用官方测试套件**：确保兼容性
- **边界测试**：测试溢出、下溢等边界情况

### 代码组织建议
```
src/
├── evm.zig           # 主模块
├── types.zig         # 基础类型定义（U256, Address, etc.）
├── context.zig       # 执行上下文
├── stack.zig         # 栈实现
├── memory.zig        # 内存实现
├── storage.zig       # 存储实现
├── opcodes.zig       # 操作码定义
├── gas.zig           # Gas 计算
├── instructions/     # 指令实现
│   ├── arithmetic.zig
│   ├── stack_ops.zig
│   ├── control.zig
│   ├── call.zig
│   └── ...
└── tests/            # 测试代码
```

---

## 里程碑

- **Milestone 1（阶段 1-2）**：完成基础数据结构和字节码解析
- **Milestone 2（阶段 3-4）**：实现基础指令和 Gas 计算
- **Milestone 3（阶段 5-6）**：实现控制流和存储
- **Milestone 4（阶段 7-8）**：完成所有指令和测试
- **Milestone 5（阶段 9）**：文档和发布

---

## 预估时间

- **总计**：12-18 周（3-4.5 个月）
- **核心开发**：8-12 周
- **测试与优化**：3-4 周
- **文档与发布**：1-2 周

*注：实际时间可能因个人经验和复杂度而有所不同*
