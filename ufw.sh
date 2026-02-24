#!/bin/bash

# ==========================================
# UFW 快捷管理菜单 (增加冲突检查版)
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. 冲突检测函数
check_conflicts() {
    # 检查 firewalld (常见于 CentOS/AlmaLinux，但也可能存在于 Debian/Ubuntu)
    if systemctl is-active --quiet firewalld; then
        echo -e "${YELLOW}检测到 firewalld 正在运行，这可能与 UFW 冲突。${NC}"
        read -p "是否关闭并禁用 firewalld? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            systemctl stop firewalld
            systemctl disable firewalld
            echo -e "${GREEN}firewalld 已关闭并禁用。${NC}"
        fi
    fi

    # 检查原生 iptables 规则 (UFW 是基于 iptables 的，但如果用户手动配置过规则，可能需要清理)
    # 这里我们通过检查是否有自定义规则（非空规则）来判断
    if command -v iptables &> /dev/null; then
        # 如果 iptables-save 输出的规则行数较多（超过基础框架），提示用户
        RULE_COUNT=$(iptables-save | wc -l)
        if [ "$RULE_COUNT" -gt 10 ]; then
            echo -e "${YELLOW}检测到系统当前已存在较多 iptables 规则。${NC}"
            echo -e "${RED}警告：直接清空可能导致正在运行的其他服务断网。${NC}"
            read -p "是否清空当前所有原生 iptables 规则并交给 UFW 管理? (y/n): " confirm_iptables
            if [[ "$confirm_iptables" == "y" || "$confirm_iptables" == "Y" ]]; then
                iptables -F
                iptables -X
                iptables -t nat -F
                iptables -t nat -X
                iptables -t mangle -F
                iptables -t mangle -X
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
                iptables -P OUTPUT ACCEPT
                echo -e "${GREEN}iptables 原生规则已清空。${NC}"
            fi
        fi
    fi
}

# 2. 防失联逻辑
auto_allow_ssh() {
    echo -e "${CYAN}正在执行安全自检...${NC}"
    # 检测 SSH 端口
    SSH_PORT=$(ss -tlnp | grep -w 'sshd' | awk '{print $4}' | awk -F':' '{print $NF}' | head -n 1)
    [ -z "$SSH_PORT" ] && SSH_PORT=22
    
    echo -e "自动放行 SSH 端口: ${GREEN}$SSH_PORT${NC}"
    ufw allow "$SSH_PORT"/tcp >/dev/null 2>&1
}

# 3. 菜单主逻辑
show_menu() {
    # 启动时先进行一次冲突检查
    check_conflicts

    while true; do
        echo -e "\n${CYAN}====================================${NC}"
        echo -e "${GREEN}       UFW 快捷管理菜单 v1.1        ${NC}"
        echo -e "${CYAN}====================================${NC}"
        echo "1. 查看状态 (Status)"
        echo "2. 开启 UFW (Enable) - 自动防锁"
        echo "3. 关闭 UFW (Disable)"
        echo "4. 放行端口 (Allow)"
        echo "5. 封禁端口 (Deny)"
        echo "6. 删除规则 (Delete)"
        echo "7. 运行冲突检查 (Check Conflicts)"
        echo "0. 退出菜单 (Exit)"
        echo -e "${CYAN}====================================${NC}"
        
        read -p "选择操作: " choice
        
        case $choice in
            1) ufw status numbered ;;
            2) 
                auto_allow_ssh
                ufw --force enable 
                ;;
            3) ufw disable ;;
            4) 
                read -p "输入端口: " port
                ufw allow "$port"
                ;;
            5)
                read -p "输入端口: " port
                ufw deny "$port"
                ;;
            6)
                ufw status numbered
                read -p "输入规则编号: " rule_num
                [ -z "$rule_num" ] || ufw --force delete "$rule_num"
                ;;
            7) check_conflicts ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效输入${NC}" ;;
        esac
    done
}

show_menu
