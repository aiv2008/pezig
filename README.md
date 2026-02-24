# pezig

基于 PEG（Parsing Expression Grammar）的通用解析器，使用 Zig 实现，设计上参考 [Pest](https://pest.rs/)。支持声明式语法定义、规则解析与运行时匹配。

## 概述

- **PEG 规则解析**：解析 PEG 语法字符串，构建 Rule AST（`~` `|` `?` `+` `*` `!` `&` `_` `@` 等操作符）。
- **运行时匹配引擎**：根据 Rule AST 对输入字符串进行匹配，返回 `MatchResult`（含正则匹配、原子、静默等）。
- **依赖**：可选依赖 [zig-regex](https://github.com/zig-utils/zig-regex)（通过 `build.zig.zon` 的 path 或 url 配置）。

## 快速开始

```bash
# 构建
zig build

# 运行示例
zig build run

# 运行所有测试
zig build test

# 仅运行 src/paser_test.zig 中的测试
zig build test-paser
```

## 项目结构

```
pezig/
├── README.md                 # 本文件（项目说明）
├── build.zig / build.zig.zon # 构建与依赖
├── docs/
│   ├── DESIGN.md           # 设计文档（架构、核心组件、关键特性、实现步骤规划）
│   └── IMPLEMENTATION.md   # 实现文档（当前进度、匹配引擎指南、测试指南）
└── src/
    ├── ast.zig       # Rule、MatchResult 等 AST 与结果类型
    ├── errors.zig    # 错误类型
    ├── parser.zig    # PEZParser（规则解析）、RuntimeParser（匹配引擎）
    ├── paser_test.zig # 解析/匹配测试（含 matchRegex 等）
    ├── main.zig      # 示例入口
    └── root.zig      # 模块根
```

## 更多文档

- **设计**：架构、核心组件、关键特性与实现步骤规划 → [docs/DESIGN.md](docs/DESIGN.md)
- **实现**：当前实现进度、matchRegex 说明、匹配引擎实现步骤、测试用例与调试技巧 → [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)
