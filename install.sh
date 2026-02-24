#!/bin/bash

# ==========================================
# UFW 快捷菜单 (ufwm) 一键安装脚本
# ==========================================

# 定义颜色输出，提升交互体验
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 恢复默认颜色

# 定义 GitHub 仓库信息
GITHUB_USER="sockc"
REPO_NAME="ufwm"           # 如果你的仓库叫别的名字，请修改这里
SCRIPT_NAME="ufwm.sh"      # 你的主菜单脚本名称
CMD_NAME="ufwm"            # 用户在终端输入的快捷命令
INSTALL_DIR="/usr/local/bin"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/${SCRIPT_NAME}"

echo -e "${GREEN}开始安装 UFW 快捷菜单 (${CMD_NAME})...${NC}"

# 1. 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误: 防火墙配置需要管理员权限。${NC}"
  echo -e "请使用 root 用户或 sudo 运行此脚本 (例如: sudo bash install.sh)"
  exit 1
fi

# 2. 检查依赖工具 (curl 和 ufw)
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 未找到 curl 工具。${NC}"
    echo "请先运行 apt-get install curl 或 yum install curl 进行安装。"
    exit 1
fi

if ! command -v ufw &> /dev/null; then
    echo -e "${YELLOW}警告: 当前系统似乎未安装 UFW。${NC}"
    echo "你可以稍后通过包管理器安装 (例如: apt install ufw)。"
fi

# 3. 下载并安装主脚本
echo "正在从 GitHub (${GITHUB_USER}/${REPO_NAME}) 下载最新脚本..."
curl -sSL "$RAW_URL" -o "${INSTALL_DIR}/${CMD_NAME}"

# 4. 验证下载并设置权限
if [ $? -eq 0 ] && [ -s "${INSTALL_DIR}/${CMD_NAME}" ]; then
    chmod +x "${INSTALL_DIR}/${CMD_NAME}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}安装成功！${NC}"
    echo -e "可执行文件已保存至: ${INSTALL_DIR}/${CMD_NAME}"
    echo -e "现在，您可以在终端任意位置输入 ${GREEN}${CMD_NAME}${NC} 来唤出防火墙菜单。"
    echo -e "${GREEN}====================================${NC}"
else
    echo -e "${RED}下载失败！请检查以下几点：${NC}"
    echo "1. 您的 VPS 网络是否能正常访问 GitHub RAW 域名。"
    echo "2. GitHub 仓库名 (${REPO_NAME}) 和脚本名 (${SCRIPT_NAME}) 是否正确。"
    echo "3. 仓库是否已设置为 Public (公开)。"
    # 清理可能下载的空文件或错误文件
    rm -f "${INSTALL_DIR}/${CMD_NAME}" 
    exit 1
fi
