#!/bin/bash

# ===============================================================
# 项目名称: UFWM (UFW Management Menu)
# 版本: v1.4 (Final)
# 作者: sockc
# 功能: 交互式管理 UFW，集成 Tailscale 兼容、Docker 修复及防失联逻辑
# ===============================================================

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- 权限检查 ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 用户或 sudo 运行此脚本。${NC}"
    exit 1
fi

# --- 核心函数 ---

# 1. 获取 Tailscale 状态
get_tailscale_info() {
    if command -v tailscale &> /dev/null; then
        local ts_ip=$(tailscale ip -4 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$ts_ip" ]; then
            echo -e "   Tailscale IP : ${BLUE}${ts_ip}${NC} ${GREEN}(在线)${NC}"
        else
            echo -e "   Tailscale    : ${YELLOW}已安装但未连接${NC}"
        fi
    else
        echo -e "   Tailscale    : ${NC}未检测到"
    fi
}

# 2. 顶部状态栏
get_status_banner() {
    local raw_status=$(ufw status | head -n 1 | awk '{print $2}')
    local pub_ip=$(curl -s --connect-timeout 2 https://api64.ipify.org || echo "无法获取IP")
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "   ${BLUE}UFW 快捷管理菜单 v1.4${NC}   作者: ${YELLOW}sockc${NC}"
    echo -e "   服务器公网 IP: ${WHITE}$pub_ip${NC}"
    get_tailscale_info
    
    if [[ "$raw_status" == "active" ]]; then
        echo -e "   防火墙状态  : ${GREEN}● Active (正在保护中)${NC}"
    else
        echo -e "   防火墙状态  : ${RED}○ Inactive (未受保护)${NC}"
    fi
    echo -e "${CYAN}================================================${NC}"
}

# 3. 防失联逻辑 (SSH + Tailscale + Loopback)
auto_allow_safe_access() {
    echo -e "${YELLOW}正在执行防失联安全自检...${NC}"
    
    # 强制放行本地回环 (确保 127.0.0.1 永远畅通)
    ufw allow in on lo >/dev/null 2>&1
    ufw allow out on lo >/dev/null 2>&1

    # 自动放行 SSH
    local ssh_port=$(ss -tlnp | grep -w 'sshd' | awk '{print $4}' | awk -F':' '{print $NF}' | head -n 1)
    [[ -z "$ssh_port" ]] && ssh_port=22
    ufw allow "$ssh_port"/tcp >/dev/null 2>&1
    echo -e "放行 SSH 端口: ${GREEN}$ssh_port${NC}"

    # 自动放行 Tailscale 接口
    if ip link show tailscale0 &> /dev/null; then
        ufw allow in on tailscale0 >/dev/null 2>&1
        echo -e "放行 Tailscale 接口: ${GREEN}已完成${NC}"
    fi
}

# 4. 修复 Docker 绕过 UFW 的问题
fix_docker_bypass() {
    echo -e "${YELLOW}正在检查并修复 Docker 绕过防火墙问题...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 系统未安装 Docker。${NC}"
        return
    fi

    if grep -q "DOCKER-USER" /etc/ufw/after.rules; then
        echo -e "${CYAN}补丁已存在，无需重复操作。${NC}"
    else
        cp /etc/ufw/after.rules /etc/ufw/after.rules.bak
        cat <<EOF >> /etc/ufw/after.rules

# BEGIN UFW AND DOCKER FIX (by sockc)
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16
-A DOCKER-USER -j ufw-user-forward
COMMIT
# END UFW AND DOCKER FIX
EOF
        echo -e "${GREEN}Docker 补丁已应用！正在重启 UFW...${NC}"
        ufw reload
    fi
}

# 5. 环境冲突检测
check_conflicts() {
    echo -e "\n${YELLOW}[!] 正在检查冲突...${NC}"
    if systemctl is-active --quiet firewalld; then
        read -p "发现 firewalld，是否关闭? (y/n): " c
        [[ "$c" == "y" ]] && (systemctl stop firewalld; systemctl disable firewalld)
    fi
    if command -v iptables &> /dev/null; then
        read -p "是否清空原生 iptables 规则以防冲突? (y/n): " c2
        [[ "$c2" == "y" ]] && (iptables -F; iptables -X; iptables -t nat -F; iptables -P INPUT ACCEPT)
    fi
}

# --- 主菜单 ---
show_menu() {
    while true; do
        clear
        get_status_banner
        echo -e " 1. 查看详细规则列表 (Status Numbered)"
        echo -e " 2. ${GREEN}开启 UFW${NC} (自动放行 SSH/TS/回环)"
        echo -e " 3. ${RED}关闭 UFW${NC}"
        echo -e " 4. 放行指定端口 (Allow)"
        echo -e " 5. 封禁指定端口 (Deny)"
        echo -e " 6. 删除已有规则 (Delete)"
        echo -e " 7. 运行环境冲突检查 (Check)"
        echo -e " 8. ${BLUE}修复 Docker 绕过防火墙问题${NC}"
        echo -e " 0. 退出脚本 (Exit)"
        echo -e "${CYAN}================================================${NC}"
        read -p "请输入选项 [0-8]: " choice

        case $choice in
            1) echo -e "\n${YELLOW}--- 详细规则 ---${NC}"; ufw status numbered; read -p "按回车返回..." ;;
            2) echo -e "\n"; auto_allow_safe_access; ufw --force enable; sleep 2 ;;
            3) ufw disable; sleep 2 ;;
            4) read -p "输入放行端口: " port; [[ -n "$port" ]] && ufw allow "$port"; sleep 1 ;;
            5) read -p "输入封禁端口: " port; [[ -n "$port" ]] && ufw deny "$port"; sleep 1 ;;
            6) ufw status numbered; read -p "输入规则编号: " num; [[ -n "$num" ]] && ufw --force delete "$num"; sleep 1 ;;
            7) check_conflicts; read -p "按回车返回..." ;;
            8) fix_docker_bypass; read -p "按回车返回..." ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

show_menu
