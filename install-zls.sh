#!/bin/bash
# ZLS (Zig Language Server) 安装脚本 for Fedora

set -e

echo "开始安装 ZLS (Zig Language Server)..."

# 检查 Zig 是否已安装
if ! command -v zig &> /dev/null; then
    echo "错误: 未找到 Zig 编译器"
    echo "请先安装 Zig:"
    echo "  sudo dnf install zig"
    echo "  或者从 https://ziglang.org/download/ 下载"
    exit 1
fi

echo "✓ 找到 Zig: $(zig version)"

# 安装必要的依赖（如果需要）
echo "检查构建依赖..."
if ! command -v git &> /dev/null; then
    echo "安装 git..."
    sudo dnf install -y git
fi

# 克隆或更新 ZLS 仓库
ZLS_DIR="$HOME/.local/share/zls"
if [ -d "$ZLS_DIR" ]; then
    echo "ZLS 仓库已存在，更新中..."
    cd "$ZLS_DIR"
    git pull
else
    echo "克隆 ZLS 仓库..."
    mkdir -p "$HOME/.local/share"
    git clone https://github.com/zigtools/zls.git "$ZLS_DIR"
    cd "$ZLS_DIR"
fi

# 检测 Zig 版本并选择兼容的 ZLS 版本
ZIG_VERSION=$(zig version | cut -d' ' -f1)
echo "检测到 Zig 版本: $ZIG_VERSION"

# 如果是 0.15.x，使用 0.15.1 标签
if [[ "$ZIG_VERSION" == "0.15"* ]]; then
    echo "切换到 ZLS 0.15.1 版本（与 Zig $ZIG_VERSION 兼容）..."
    git checkout 0.15.1 2>/dev/null || git fetch origin tag 0.15.1 && git checkout 0.15.1
elif [[ "$ZIG_VERSION" == "0.14"* ]]; then
    echo "切换到 ZLS 0.14.0 版本（与 Zig $ZIG_VERSION 兼容）..."
    git checkout 0.14.0 2>/dev/null || git fetch origin tag 0.14.0 && git checkout 0.14.0
fi

# 构建 ZLS
echo "构建 ZLS (这可能需要几分钟)..."
zig build -Doptimize=ReleaseSafe

# 安装到本地 bin 目录
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
cp zig-out/bin/zls "$INSTALL_DIR/zls"

# 确保 ~/.local/bin 在 PATH 中
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "警告: $HOME/.local/bin 不在 PATH 中"
    echo "请将以下行添加到 ~/.bashrc 或 ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# 验证安装
if [ -f "$INSTALL_DIR/zls" ]; then
    echo ""
    echo "✓ ZLS 安装成功!"
    echo "  位置: $INSTALL_DIR/zls"
    echo "  版本: $($INSTALL_DIR/zls --version 2>&1 || echo '无法获取版本')"
    echo ""
    echo "如果 zls 命令不可用，请确保 ~/.local/bin 在 PATH 中"
else
    echo "错误: 安装失败"
    exit 1
fi

