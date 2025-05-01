#!/bin/bash

# 设置脚本在出错时立即退出
set -e

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 定义 GitHub 仓库信息 (请替换为你的实际信息)
GITHUB_USER="your_github_username"
GITHUB_REPO="your_repository_name"
SCRIPT_NAME="debian12_config_tool.sh" # 请确保与你实际的文件名一致

echo ""
echo "             ${GREEN}Debian 12 一键配置交互式脚本${NC}               "
echo "                           作者：s0meones                           "
echo ""

# 函数：显示主菜单
show_main_menu() {
  echo ""
  echo "${YELLOW}请选择要执行的操作：${NC}"
  echo "${BLUE}1.${NC} 配置系统环境"
  echo "${BLUE}2.${NC} 测试脚本合集"
  echo "${BLUE}3.${NC} 更新本脚本"
  echo "${BLUE}0.${NC} 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}

# 函数：更新本脚本
update_script() {
  echo "${YELLOW}正在尝试更新脚本...${NC}"
  if command -v curl >/dev/null 2>&1; then
    curl -sSL "https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/${SCRIPT_NAME}" -o "${SCRIPT_NAME}"
    if [ $? -eq 0 ]; then
      chmod +x "${SCRIPT_NAME}"
      echo "${GREEN}脚本更新成功！请重新运行以应用最新版本。${NC}"
    else
      echo "${RED}更新脚本失败，请检查网络连接或 GitHub 仓库信息。${NC}"
    fi
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${SCRIPT_NAME}" "https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/${SCRIPT_NAME}"
    if [ $? -eq 0 ]; then
      chmod +x "${SCRIPT_NAME}"
      echo "${GREEN}脚本更新成功！请重新运行以应用最新版本。${NC}"
    else
      echo "${RED}更新脚本失败，请检查网络连接或 GitHub 仓库信息。${NC}"
    fi
  else
    echo "${RED}未找到 curl 或 wget 命令，无法自动更新脚本。${NC}"
    echo "${YELLOW}请手动从 GitHub 下载最新版本并替换。${NC}"
  fi
  read -n 1 -s -p "${YELLOW}按任意键返回主菜单...${NC}"
  echo ""
}

# 函数：配置系统环境子菜单
config_system_env() {
  while true; do
    echo ""
    echo "${YELLOW}配置系统环境：${NC}"
    echo "${BLUE}1.${NC} 更新系统 (apt update && apt upgrade -y)"
    echo "${BLUE}2.${NC} 安装系统必要环境 (apt install unzip curl wget git sudo -y)"
    echo "${BLUE}3.${NC} 开启 BBR v3 加速"
    echo "${BLUE}4.${NC} 开启 BBR v3 + FQ 策略 (如果 BBR v3 已启用)"
    echo "${BLUE}5.${NC} 开放所有端口 (清空防火墙规则)"
    echo "${BLUE}6.${NC} 切换 IPv4/IPv6 优先"
    echo "${BLUE}9.${NC} 返回主菜单"
    echo "${BLUE}0.${NC} 退出脚本${NC}"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "$sub_choice" in
      1)
        echo "${YELLOW}正在更新系统，请稍候...${NC}"
        sudo apt update -y
        sudo apt upgrade -y
        echo "${GREEN}系统更新完成。${NC}"
        ;;
      2)
        echo "${YELLOW}正在安装必要环境，请稍候...${NC}"
        sudo apt install unzip curl wget git sudo -y
        echo "${GREEN}必要环境安装完成。${NC}"
        ;;
      3)
        enable_bbrv3
        ;;
      4)
        enable_bbr_fq
        ;;
      5)
        open_all_ports
        ;;
      6)
        toggle_ipv4_ipv6_preference
        ;;
      9)
        break # 返回主菜单
        ;;
      0)
        echo "${YELLOW}退出脚本。${NC}"
        exit 0
        ;;
      *)
        echo "${RED}无效的指令，请重新输入。${NC}"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "$sub_choice" != "9" ]; then
      read -n 1 -s -p "${YELLOW}按任意键继续...${NC}"
      echo "" # 为了换行
    fi
  done
}

# 函数：开启 BBR v3 加速
enable_bbrv3() {
  echo "${YELLOW}正在尝试开启 BBR v3 加速...${NC}"
  # 检查内核版本是否支持 BBR v3 (通常 Linux 5.15 及以上)
  kernel_version=$(uname -r | awk -F'.' '{print $1"."$2}')
  if (( $(echo "$kernel_version" | bc -l) >= $(echo "5.15" | bc -l) )); then
    sudo sysctl -w net.core.default_qdisc=cake
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr3
    echo "${GREEN}BBR v3 加速已开启。${NC}"
    # 持久化配置
    sudo sh -c "echo 'net.core.default_qdisc=cake' >> /etc/sysctl.conf"
    sudo sh -c "echo 'net.ipv4.tcp_congestion_control=bbr3' >> /etc/sysctl.conf"
    sudo sysctl -p
  else
    echo "${YELLOW}当前内核版本 ($kernel_version) 可能不支持 BBR v3，跳过。${NC}"
  fi
}

# 函数：开启 BBR v3 + FQ 策略
enable_bbr_fq() {
  echo "${YELLOW}正在尝试开启 BBR v3 + FQ 策略...${NC}"
  # 假设已经开启了 BBR v3，这里只修改拥塞控制算法
  current_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
  if [ "$current_congestion_control" == "bbr3" ]; then
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr3
    echo "${GREEN}BBR v3 + FQ 策略已开启。${NC}"
    # 持久化配置
    sudo sh -c "echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf"
    sudo sh -c "echo 'net.ipv4.tcp_congestion_control=bbr3' >> /etc/sysctl.conf"
    sudo sysctl -p
  else
    echo "${YELLOW}请先开启 BBR v3，才能启用 BBR v3 + FQ 策略。${NC}"
  fi
}

# 函数：开放所有端口 (清空防火墙规则)
open_all_ports() {
  echo "${RED}警告：您将要开放所有端口，这可能会带来安全风险！${NC}"
  read -p "您确定要继续吗？ (y/N): " confirm_open_ports
  if [[ "$confirm_open_ports" == "y" || "$confirm_open_ports" == "Y" ]]; then
    echo "${YELLOW}正在清空防火墙规则...${NC}"
    sudo iptables -F
    sudo iptables -X
    sudo iptables -Z
    sudo ip6tables -F
    sudo ip6tables -X
    sudo ip6tables -Z
    echo "${GREEN}防火墙规则已清空，所有端口已开放。${NC}"
  else
    echo "${YELLOW}已取消开放所有端口的操作。${NC}"
  fi
}

# 函数：切换 IPv4/IPv6 优先
toggle_ipv4_ipv6_preference() {
  current_preference=$(sysctl net.ipv6.prefer_inet6 | awk '{print $3}')
  if [ "$current_preference" -eq 0 ]; then
    echo "${YELLOW}当前 IPv4 优先。切换到 IPv6 优先...${NC}"
    sudo sysctl -w net.ipv6.prefer_inet6=1
    sudo sh -c "echo 'net.ipv6.prefer_inet6=1' >> /etc/sysctl.conf"
    sudo sysctl -p
    echo "${GREEN}已切换到 IPv6 优先。${NC}"
  else
    echo "${YELLOW}当前 IPv6 优先。切换到 IPv4 优先...${NC}"
    sudo sysctl -w net.ipv6.prefer_inet6=0
    sudo sh -c "echo 'net.ipv6.prefer_inet6=0' >> /etc/sysctl.conf"
    sudo sysctl -p
    echo "${GREEN}已切换到 IPv4 优先。${NC}"
  fi
}

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  while true; do
    echo ""
    echo "${YELLOW}测试脚本合集：${NC}"
    echo "${BLUE}1.${NC} NodeQuality 测试 (bash <(curl -sL https://run.NodeQuality.com))"
    echo "${BLUE}9.${NC} 返回主菜单"
    echo "${BLUE}0.${NC} 退出脚本${NC}"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "$sub_choice" in
      1)
        echo "${YELLOW}正在运行 NodeQuality 测试脚本，请稍候...${NC}"
        bash <(curl -sL https://run.NodeQuality.com)
        echo "${GREEN}NodeQuality 测试完成。${NC}"
        ;;
      9)
        break # 返回主菜单
        ;;
      0)
        echo "${YELLOW}退出脚本。${NC}"
        exit 0
        ;;
      *)
        echo "${RED}无效的指令，请重新输入。${NC}"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "$sub_choice" != "9" ]; then
      read -n 1 -s -p "${YELLOW}按任意键继续...${NC}"
      echo "" # 为了换行
    fi
  done
}

# 主循环
while true; do
  show_main_menu
  case "$main_choice" in
    1)
      config_system_env
      ;;
    2)
      test_scripts_menu
      ;;
    3)
      update_script
      ;;
    0)
      echo "${YELLOW}退出脚本。${NC}"
      exit 0
      ;;
    *)
      echo "${RED}无效的指令，请重新输入。${NC}"
      ;;
  esac
done
