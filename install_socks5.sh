#!/bin/bash

# SOCKS5 一键安装脚本 - GitHub版本
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/Cd1s/install_socks5/main/install_socks5.sh)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub仓库信息
GITHUB_RAW_URL="https://raw.githubusercontent.com/Cd1s/install_socks5/main"

echo -e "${BLUE}"
cat << "EOF"
 ____   ___   ____ _  ______  ____  
/ ___| / _ \ / ___| |/ / ___||  _ \ 
\___ \| | | | |   | ' /\___ \| |_) |
 ___) | |_| | |___| . \ ___) |  __/ 
|____/ \___/ \____|_|\_\____/|_|    

    SOCKS5 一键安装脚本 2025
    支持 CentOS/Ubuntu/Debian/Alpine
EOF
echo -e "${NC}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要root权限运行此脚本${NC}"
    echo "請使用: sudo bash <(curl -fsSL ${GITHUB_RAW_URL}/install_socks5.sh)"
    exit 1
fi

# 创建临时目录
TEMP_DIR="/tmp/socks5_install_$$"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# 下载主安装脚本
echo -e "${GREEN}正在下载安装脚本...${NC}"
if ! curl -fsSL "${GITHUB_RAW_URL}/socks5_install.sh" -o socks5_install.sh; then
    echo -e "${RED}下载失败，请检查网络连接${NC}"
    exit 1
fi

# 赋予执行权限并运行
chmod +x socks5_install.sh
echo -e "${GREEN}启动安装程序...${NC}"
echo

# 执行主安装脚本
./socks5_install.sh

# 清理临时文件
cd /
rm -rf "$TEMP_DIR"
