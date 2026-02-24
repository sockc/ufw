#!/bin/bash

# ===============================================================
# 项目名称: UFWM (UFW Management Menu)
# 作者: sockc
# 仓库: https://github.com/sockc/ufw
# 功能: 交互式管理 UFW 防火墙，内置防失联与冲突检测
# ===============================================================

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 权限检查 ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 用户或 sudo 运行此脚本。${NC}"
    exit 1
fi

# --- 功能函数 ---

# 1. 顶部状态栏逻辑
get_status_banner() {
    local raw_status=$(ufw status | head -n 1 | awk '{print $2}')
    # 获取公网 IP (增加超时防止卡顿)
    local pub_ip=$(curl -s --connect-timeout 2 https://api64.ipify.org || echo "无法获取IP")
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "   ${BLUE}UFW 快捷管理菜单 v1.2${NC}   作者: ${YELLOW}sockc${NC}"
    echo -e "   服务器 IP : ${WHITE}$pub_ip${NC}"
    
    if [[ "$raw_status" == "active" ]]; then
        echo -e "   防火墙状态: ${GREEN}● Active (正在保护中)${NC}"
    else
        echo -e "   防火墙状态: ${RED}○ Inactive (未受保护)${NC}"
    fi
    echo -e "${CYAN}================================================${NC}"
}

# 2. 冲突检测与清理
check_conflicts() {
    echo -e "\n${YELLOW}[!] 正在检查系统环境冲突...${NC}"
    
    # 检查 firewalld
    if systemctl is-active --quiet firewalld; then
        echo -e "${YELLOW}检测到 firewalld 正在运行，可能与 UFW 冲突。${NC}"
        read -p "是否关闭并禁用 firewalld? (y/n): " confirm
        [[ "$confirm" == "y" || "$confirm" == "Y" ]] && (systemctl stop firewalld; systemctl disable firewalld; echo -e "${GREEN}firewalld 已关闭。${NC}")
    fi

    # 检查原生 iptables 规则
    if command -v iptables &> /dev/null; then
        local rule_count=$(iptables-save | wc -l)
        if [ "$rule_count" -gt 10 ]; then
            echo -e "${YELLOW}检测到系统当前已存在较多原生 iptables 规则。${NC}"
            read -p "是否清空当前 iptables 规则并交给 UFW 管理? (y/n): " confirm_ipt
            if [[ "$confirm_ipt" == "y" || "$confirm_ipt" == "Y" ]]; then
                iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X
                iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT
                echo -e "${GREEN}iptables 原生规则已清空。${NC}"
            fi
        fi
    fi
    echo -e "${GREEN}冲突检查完成。${NC}"
    sleep 1
}

# 3. 防失联：自动放行 SSH
auto_allow_ssh() {
    echo -e "${YELLOW}正在执行防失联自检...${NC}"
    # 动态抓取 SSH 端口
    local ssh_port=$(ss -tlnp | grep -w 'sshd' | awk '{print $4}' | awk -F':' '{print $NF}' | head -n 1)
    [[ -z "$ssh_port" ]] && ssh_port=22
    
    echo -e "检测到 SSH 端口: ${GREEN}$ssh_port${NC}，正在强制放行..."
    ufw allow "$ssh_port"/tcp >/dev/null 2>&1
    echo -e "${GREEN}SSH 安全准入已配置。${NC}"
}

# --- 主菜单 ---
show_menu() {
    while true; do
        clear
        get_status_banner
        echo -e " 1. 查看详细规则列表 (Numbered)"
        echo -e " 2. ${GREEN}开启 UFW (Enable)${NC} - 附带防锁功能"
        echo -e " 3. ${RED}关闭 UFW (Disable)${NC}"
        echo -e " 4. 放行指定端口 (Allow)"
        echo -e " 5. 封禁指定端口 (Deny)"
        echo -e " 6. 删除已有规则 (Delete)"
        echo -e " 7. 运行环境冲突检查 (Check)"
        echo -e " 0. 退出脚本 (Exit)"
        echo -e "${CYAN}================================================${NC}"
        read -p "请输入选项 [0-7]: " choice

        case $choice in
            1)
                echo -e "\n${YELLOW}--- 当前防火墙详细规则 ---${NC}"
                ufw status numbered
                read -p "按回车键返回菜单..." 
                ;;
            2)
                echo -e "\n${YELLOW}--- 启动流程 ---${NC}"
                auto_allow_ssh
                ufw --force enable
                sleep 2
                ;;
            3)
                echo -e "\n${YELLOW}--- 关闭流程 ---${NC}"
                ufw disable
                sleep 2
                ;;
            4)
                echo -e "\n"
                read -p "请输入要放行的端口 (如 80 或 8080/tcp): " port
                [[ -n "$port" ]] && ufw allow "$port" && echo -e "${GREEN}端口 $port 已放行${NC}"
                sleep 1
                ;;
            5)
                echo -e "\n"
                read -p "请输入要封禁的端口: " port
                [[ -n "$port" ]] && ufw deny "$port" && echo -e "${RED}端口 $port 已封禁${NC}"
                sleep 1
                ;;
            6)
                echo -e "\n"
                ufw status numbered
                read -p "请输入要删除的规则编号: " num
                [[ -n "$num" ]] && ufw --force delete "$num"
                sleep 1
                ;;
            7)
                check_conflicts
                read -p "检查完毕，按回车键返回..."
                ;;
            0)
                echo -e "${BLUE}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入...${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 启动 ---
show_menu
