#!/bin/bash

# 设置脚本在出错时立即退出
set -e

echo ""
echo "Debian 12 一键配置交互式脚本"
echo "作者：s0meones"
echo ""

# 函数：显示主菜单
show_main_menu() {
  echo ""
  echo "请选择要执行的操作："
  echo "1. 配置系统环境"
  echo "2. 测试脚本合集"
  echo "3. 更新本脚本"
  echo "0. 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}

# 函数：更新本脚本
update_script() {
  echo "更新本脚本功能需要配置 GitHub 仓库信息才能自动完成。"
  echo "请手动从 GitHub 下载最新版本并替换。"
  read -n 1 -s -p "按任意键返回主菜单..."
  echo ""
}

# 函数：配置系统环境子菜单
config_system_env() {
  while true; do
    echo ""
    echo "配置系统环境："
    echo "1. 更新系统 (apt update && apt upgrade -y)"
    echo "2. 安装系统必要环境 (apt install unzip curl wget git sudo -y)"
    echo "3. 开启 BBR v3 加速"
    echo "4. 开放所有端口 (清空防火墙规则)"
    echo "5. 切换 IPv4/IPv6 优先"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "$sub_choice" in
      1)
        echo "正在更新系统，请稍候..."
        sudo apt update -y
        sudo apt upgrade -y
        echo "系统更新完成。"
        ;;
      2)
        echo "正在安装必要环境，请稍候..."
        sudo apt install unzip curl wget git sudo -y
        echo "必要环境安装完成。"
        ;;
      3)
        enable_bbrv3
        ;;
      4)
        open_all_ports
        ;;
      5)
        toggle_ipv4_ipv6_preference
        ;;
      9)
        break # 返回主菜单
        ;;
      0)
        echo "退出脚本。"
        exit 0
        ;;
      *)
        echo "无效的指令，请重新输入。"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "$sub_choice" != "9" ]; then
      read -n 1 -s -p "按任意键继续..."
      echo "" # 为了换行
    fi
  done
}

# 函数：开启 BBR v3 加速
enable_bbrv3() {
  echo "正在尝试开启 BBR v3 加速..."
  # 检查内核版本是否支持 BBR v3 (通常 Linux 5.15 及以上)
  kernel_version=$(uname -r | awk -F'.' '{print $1"."$2}')
  if (( $(echo "$kernel_version" | bc -l) >= $(echo "5.15" | bc -l) )); then
    sudo sysctl -w net.core.default_qdisc=cake
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr3
    echo "BBR v3 加速已开启。"
    # 持久化配置
    sudo sh -c "echo 'net.core.default_qdisc=cake' >> /etc/sysctl.conf"
    sudo sh -c "echo 'net.ipv4.tcp_congestion_control=bbr3' >> /etc/sysctl.conf"
    sudo sysctl -p

    # 询问是否启用 BBR v3 + FQ
    read -p "是否同时启用 BBR v3 + FQ 策略？ (y/N): " enable_fq
    if [[ "$enable_fq" == "y" || "$enable_fq" == "Y" ]]; then
      enable_bbr_fq
    fi
  else
    echo "当前内核版本 ($kernel_version) 可能不支持 BBR v3，跳过。"
  fi
}

# 函数：开启 BBR v3 + FQ 策略
enable_bbr_fq() {
  echo "正在尝试开启 BBR v3 + FQ 策略..."
  sudo sysctl -w net.core.default_qdisc=fq
  sudo sysctl -w net.ipv4.tcp_congestion_control=bbr3
  echo "BBR v3 + FQ 策略已开启。"
  # 持久化配置
  sudo sh -c "echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf"
  sudo sh -c "echo 'net.ipv4.tcp_congestion_control=bbr3' >> /etc/sysctl.conf"
  sudo sysctl -p

  # 询问是否重启
  read -p "策略已更改，是否立即重启服务器以应用更改？ (y/N): " reboot_choice
  if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
    echo "正在重启服务器..."
    sudo reboot
  fi
}

# 函数：开放所有端口 (清空防火墙规则)
open_all_ports() {
  echo "警告：您将要开放所有端口，这可能会带来安全风险！"
  read -p "您确定要继续吗？ (y/N): " confirm_open_ports
  if [[ "$confirm_open_ports" == "y" || "$confirm_open_ports" == "Y" ]]; then
    echo "正在清空防火墙规则..."
    sudo iptables -F
    sudo iptables -X
    sudo iptables -Z
    sudo ip6tables -F
    sudo ip6tables -X
    sudo ip6tables -Z
    echo "防火墙规则已清空，所有端口已开放。"
  else
    echo "已取消开放所有端口的操作。"
  fi
}

# 函数：切换 IPv4/IPv6 优先
toggle_ipv4_ipv6_preference() {
  # 检查 /proc/sys/net/ipv6/prefer_inet6 文件是否存在
  if [ -f /proc/sys/net/ipv6/prefer_inet6 ]; then
    current_preference=$(sysctl net.ipv6.prefer_inet6 | awk '{print $3}')
    if [ "$current_preference" -eq 0 ]; then
      echo "当前 IPv4 优先。切换到 IPv6 优先..."
      sudo sysctl -w net.ipv6.prefer_inet6=1
      sudo sh -c "echo 'net.ipv6.prefer_inet6=1' >> /etc/sysctl.conf"
      sudo sysctl -p
      echo "已切换到 IPv6 优先。"
    else
      echo "当前 IPv6 优先。切换到 IPv4 优先..."
      sudo sysctl -w net.ipv6.prefer_inet6=0
      sudo sh -c "echo 'net.ipv6.prefer_inet6=0' >> /etc/sysctl.conf"
      sudo sysctl -p
      echo "已切换到 IPv4 优先。"
    fi
  else
    echo "警告：IPv6 功能可能未启用，无法切换 IPv4/IPv6 优先。"
  fi
}

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  while true; do
    echo ""
    echo "测试脚本合集："
    echo "1. NodeQuality 测试 (bash <(curl -sL https://run.NodeQuality.com))"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "$sub_choice" in
      1)
        echo "正在运行 NodeQuality 测试脚本，请稍候..."
        bash <(curl -sL https://run.NodeQuality.com)
        echo "NodeQuality 测试完成。"
        ;;
      9)
        break # 返回主菜单
        ;;
      0)
        echo "退出脚本。"
        exit 0
        ;;
      *)
        echo "无效的指令，请重新输入。"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "$sub_choice" != "9" ]; then
      read -n 1 -s -p "按任意键继续..."
      echo "" # 为了换行
    fi
  done
}

# 主循环
while true; do
  show_main_menu
  case "$main_choice" in
    1) config_system_env ;;
    2) test_scripts_menu ;;
    3) update_script ;;
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。" ;;
  esac
done
