#!/bin/bash

# ==========================================
# UFW 快捷管理菜单 (核心功能脚本)
# ==========================================

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. 权限检查：确保后续 UFW 命令能正常执行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误: 请使用 root 用户或 sudo 运行此命令。${NC}"
  exit 1
fi

# 2. 核心功能：防翻车 - 自动检测并放行 SSH 端口
auto_allow_ssh() {
    echo -e "${CYAN}正在检测当前 SSH 监听端口...${NC}"
    # 通过 ss 命令动态抓取 sshd 的监听端口
    SSH_PORT=$(ss -tlnp | grep -w 'sshd' | awk '{print $4}' | awk -F':' '{print $NF}' | head -n 1)
    
    # 如果抓取失败，后备回退到默认的 22 端口
    if [ -z "$SSH_PORT" ]; then
        echo -e "${YELLOW}未能动态检测到 SSH 端口，将默认放行 22 端口。${NC}"
        SSH_PORT=22
    else
        echo -e "${GREEN}检测到 SSH 端口为: ${SSH_PORT}${NC}"
    fi

    echo "正在放行 SSH 端口 ($SSH_PORT)..."
    ufw allow "$SSH_PORT"/tcp >/dev/null 2>&1
    echo -e "${GREEN}SSH 端口已安全放行。${NC}"
}

# 3. 菜单与交互逻辑 (while / case 框架)
show_menu() {
    while true; do
        echo -e "\n${CYAN}====================================${NC}"
        echo -e "${GREEN}       UFW 快捷管理菜单 v1.0        ${NC}"
        echo -e "${CYAN}====================================${NC}"
        echo "1. 查看防火墙状态 (Status)"
        echo "2. 开启防火墙 (Enable) - 附带防失联保护"
        echo "3. 关闭防火墙 (Disable)"
        echo "4. 放行指定端口 (Allow)"
        echo "5. 封禁指定端口 (Deny)"
        echo "6. 删除已有规则 (Delete)"
        echo "0. 退出菜单 (Exit)"
        echo -e "${CYAN}====================================${NC}"
        
        read -p "请输入选项 [0-6]: " choice
        
        case $choice in
            1)
                echo -e "\n${YELLOW}--- 防火墙状态 ---${NC}"
                ufw status numbered
                ;;
            2)
                echo -e "\n${YELLOW}--- 开启防火墙 ---${NC}"
                auto_allow_ssh # 开启前强制调用防锁逻辑
                ufw --force enable
                echo -e "${GREEN}防火墙已成功开启！${NC}"
                ;;
            3)
                echo -e "\n${YELLOW}--- 关闭防火墙 ---${NC}"
                ufw disable
                ;;
            4)
                echo -e "\n${YELLOW}--- 放行端口 ---${NC}"
                read -p "请输入要放行的端口号 (如 80, 443, 8080/tcp): " port
                ufw allow "$port"
                echo -e "${GREEN}已放行端口: $port${NC}"
                ;;
            5)
                echo -e "\n${YELLOW}--- 封禁端口 ---${NC}"
                read -p "请输入要封禁的端口号: " port
                ufw deny "$port"
                echo -e "${GREEN}已封禁端口: $port${NC}"
                ;;
            6)
                echo -e "\n${YELLOW}--- 删除规则 ---${NC}"
                ufw status numbered
                read -p "请输入要删除的规则编号 (按 Enter 取消): " rule_num
                if [[ -n "$rule_num" ]]; then
                    ufw --force delete "$rule_num"
                    echo -e "${GREEN}规则 $rule_num 已删除。${NC}"
                fi
                ;;
            0)
                echo -e "${GREEN}已退出 UFW 快捷管理菜单。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                ;;
        esac
    done
}

# 4. 启动主菜单
show_menu
