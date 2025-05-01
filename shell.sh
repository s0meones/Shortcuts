#!/bin/bash

# 设置脚本在出错时立即退出
set -e

# 函数：清空屏幕
clear_screen() {
  clear
}

# 函数：显示主菜单
show_main_menu() {
  clear_screen
  echo ""
  echo "Debian 12 一键配置交互式脚本"
  echo "作者：s0meones"
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
  clear_screen
  echo "更新本脚本功能需要配置 GitHub 仓库信息才能自动完成。"
  echo "请手动从 GitHub 下载最新版本并替换。"
  read -n 1 -s -p "按任意键返回主菜单..."
  echo ""
}

# 函数：配置系统环境子菜单
config_system_env() {
  while true; do
    clear_screen
    echo "配置系统环境："
    echo "1. 更新系统 (apt update && apt upgrade -y)"
    echo "2. 安装系统必要环境 (apt install unzip curl wget git sudo -y)"
    echo "3. 开启/配置 BBR 加速 (使用 tcpx.sh)"
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
        read -n 1 -s -p "按任意键继续..."
        ;;
      2)
        echo "正在安装必要环境，请稍候..."
        sudo apt install unzip curl wget git sudo -y
        echo "必要环境安装完成。"
        read -n 1 -s -p "按任意键继续..."
        ;;
      3)
        enable_bbr_with_tcpx
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
  done
}

# 函数：使用 tcpx.sh 开启/配置 BBR 加速
enable_bbr_with_tcpx() {
  clear_screen
  echo "正在下载并执行 tcpx.sh 脚本以开启/配置 BBR 加速..."
  wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh"
  if [ -f tcpx.sh ]; then
    chmod +x tcpx.sh
    ./tcpx.sh
    rm -f tcpx.sh # 执行完毕后删除脚本

    # 询问是否重启
    read -p "tcpx.sh 脚本已执行完毕，是否立即重启服务器以应用更改？ (y/N): " reboot_choice
    if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
      echo "正在重启服务器..."
      sudo reboot
    fi
  else
    echo "下载 tcpx.sh 脚本失败，无法开启/配置 BBR 加速。"
  fi
  read -n 1 -s -p "按任意键继续..."
}

# 函数：开启 BBR + FQ 策略 (保持不变，但不再直接调用)
enable_bbr_fq() {
  echo "正在尝试开启 BBR + FQ 策略..."
  sudo sysctl -w net.core.default_qdisc=fq
  sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
  echo "BBR + FQ 策略已开启。"
  # 持久化配置
  sudo sh -c "echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf"
  sudo sh -c "echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf"
  sudo sysctl -p

  # 询问是否重启
  read -p "策略已更改，是否立即重启服务器以应用更改？ (y/N): " reboot_choice
  if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
    echo "正在重启服务器..."
    sudo reboot
  fi
  read -n 1 -s -p "按任意键继续..."
}

# 函数：开放所有端口 (清空防火墙规则)
open_all_ports() {
  clear_screen
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
    read -n 1 -s -p "按任意键继续..."
  else
    echo "已取消开放所有端口的操作。"
    read -n 1 -s -p "按任意键继续..."
  fi
}

# 函数：切换 IPv4/IPv6 优先
toggle_ipv4_ipv6_preference() {
  clear_screen
  # 检查 /proc/sys/net/ipv6/prefer_inet6 文件是否存在
  if [ -f /proc/sys/net/ipv6/prefer_inet6 ]; then
    current_preference=$(sysctl net.ipv6.prefer_inet6 | awk '{print $3}')
    if [ "$current_preference" -eq 0 ]; then
      echo "当前 IPv4 优先。切换到 IPv6 优先..."
      sudo sysctl -w net.ipv6.prefer_inet6=1
      sudo sh -c "echo 'net.ipv6.prefer_inet6=1' >> /etc/sysctl.conf"
      sudo sysctl -p
      echo "已切换到 IPv6 优先。"
      read -n 1 -s -p "按任意键继续..."
    else
      echo "当前 IPv6 优先。切换到 IPv4 优先..."
      sudo sysctl -w net.ipv6.prefer_inet6=0
      sudo sh -c "echo 'net.ipv6.prefer_inet6=0' >> /etc/sysctl.conf"
      sudo sysctl -p
      echo "已切换到 IPv4 优先。"
      read -n 1 -s -p "按任意键继续..."
    fi
  else
    echo "警告：IPv6 功能可能未启用，无法切换 IPv4/IPv6 优先。"
    read -n 1 -s -p "按任意键继续..."
  fi
}

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  clear_screen
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
      read -n 1 -s -p "按任意键继续..."
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
