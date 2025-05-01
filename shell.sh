#!/bin/bash

# 设置脚本在出错时立即退出
set -e

# 定义脚本在 GitHub 仓库中的信息
GITHUB_USER="s0meones" # 请替换为您的 GitHub 用户名
GITHUB_REPO="Shorcuts"     # 请替换为您的 GitHub 仓库名
SCRIPT_NAME=$(basename "$0")

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
  echo "3. 富强专用"
  echo "4. 更新脚本"
  echo "0. 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}

# 函数：检查是否以 root 身份运行
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "错误：请以 root 用户身份运行此脚本。"
    exit 1
  fi
}

# 函数：发送统计信息 (占位符)
send_stats() {
  echo "统计: $1"
}

# 函数：更新脚本
update_script() {
  clear_screen
  echo "正在检查更新..."
  local latest_version_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/${SCRIPT_NAME}"
  local current_script_path="$0"
  local latest_script_path="$0.latest"

  # 下载最新的脚本
  curl -o "$latest_script_path" -L "$latest_version_url"

  if [ $? -eq 0 ]; then
    # 比较两个文件的内容
    if ! cmp -s "$current_script_path" "$latest_script_path"; then
      echo "发现新版本，正在替换旧版本..."
      mv "$latest_script_path" "$current_script_path"
      chmod +x "$current_script_path"
      echo "脚本已成功更新！请重新运行脚本以使用新版本。"
    else
      echo "当前已是最新版本。"
      rm -f "$latest_script_path" # 删除临时文件
    fi
  else
    echo "下载最新版本失败。"
  fi
  read -n 1 -s -p "按任意键返回主菜单..."
}

# 函数：配置系统环境子菜单
config_system_env() {
  check_root
  while true; do
    clear_screen
    echo "配置系统环境："
    echo "1. 更新系统"
    echo "2. 安装系统必要环境 unzip curl wget git sudo"
    echo "3. 开启/配置 BBR 加速"
    echo "4. 切换 IPv4/IPv6 优先"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice_env
    case "$sub_choice_env" in
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
        ipv4_ipv6_priority_menu
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

# 函数：使用 tcpx.sh 开启/配置 BBR 加速 (被 config_system_env 调用)
enable_bbr_with_tcpx() {
  clear_screen
  echo "正在下载并执行 tcpx.sh 脚本以开启/配置 BBR 加速..."
  wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh"
  if [ -f tcpx.sh ]; then
    chmod +x tcpx.sh
    ./tcpx.sh
    rm -f tcpx.sh # 执行完毕后删除脚本

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

# 函数：切换 IPv4/IPv6 优先子菜单 (被 config_system_env 调用)
ipv4_ipv6_priority_menu() {
  check_root
  send_stats "设置v4/v6优先级"
  while true; do
    clear_screen
    echo "设置v4/v6优先级"
    echo "------------------------"
    local ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6)

    if [ "$ipv6_disabled" -eq 1 ]; then
      echo "当前网络优先级设置: IPv4 优先"
    else
      echo "当前网络优先级设置: IPv6 优先"
    fi
    echo ""
    echo "------------------------"
    echo "1. IPv4 优先          2. IPv6 优先          3. IPv6 修复工具"
    echo "------------------------"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -e -p "选择优先的网络: " choice

    case $choice in
      1)
        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
        echo "已切换为 IPv4 优先"
        send_stats "已切换为 IPv4 优先"
        ;;
      2)
        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
        echo "已切换为 IPv6 优先"
        send_stats "已切换为 IPv6 优先"
        ;;

      3)
        clear
        bash <(curl -L -s jhb.ovh/jb/v6.sh)
        echo "该功能由jhb大神提供，感谢他！"
        send_stats "ipv6修复"
        read -n 1 -s -p "按任意键返回 v4/v6 优先级菜单..."
        ;;

      0)
        break
        ;;

      *)
        echo "无效的选择，请重新输入。"
        sleep 2
        ;;

    esac
  done
}

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  while true; do
    clear_screen
    echo "测试脚本合集："
    echo "1. NodeQuality 测试"
    echo "2. IP 质量体检"
    echo "3. 融合怪测试"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice_test
    case "$sub_choice_test" in
      1)
        echo "正在运行 NodeQuality 测试脚本，请稍候..."
        bash <(curl -sL https://run.NodeQuality.com)
        echo "NodeQuality 测试完成。"
        read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
        ;;
      2)
        echo "正在运行 IP 质量体检脚本，请稍候..."
        bash <(curl -sL IP.Check.Place)
        echo "IP 质量体检完成。"
        read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
        ;;
      3)
        echo "正在运行 融合怪测试脚本，请稍候..."
        bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
        echo "融合怪测试完成。"
        read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
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

# 函数：富强专用子菜单
fuqiang_menu() {
  while true; do
    clear_screen
    echo "富强专用："
    echo "1. 安装 3x-ui 面板"
    echo "2. 安装八合一脚本"
    echo "3. 安装 snell"
    echo "4. 安装 realm & gost 一键转发脚本"
    echo "9. 返回主菜单"
    echo "0. 退出脚本"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice_fq
    case "$sub_choice_fq" in
      1)
        echo "正在安装 3x-ui 面板，请稍候..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        echo "3x-ui 面板安装完成。"
        read -n 1 -s -p "按任意键返回富强专用菜单..."
        ;;
      2)
        echo "正在安装八合一脚本，请稍候..."
        wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
        echo "八合一脚本安装完成。"
        read -n 1 -s -p "按任意键返回富强专用菜单..."
        ;;
      3)
        echo "正在安装 snell，请稍候..."
        wget https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -O snell.sh && chmod +x snell.sh && ./snell.sh
        echo "snell 安装完成。"
        read -n 1 -s -p "按任意键返回富强专用菜单..."
        ;;
      4)
        echo "正在安装 realm & gost 一键转发脚本，请稍候..."
        wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh
        echo "realm & gost 一键转发脚本安装完成。"
        read -n 1 -s -p "按任意键返回富强专用菜单..."
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

# 主循环
while true; do
  show_main_menu
  case "$main_choice" in
    1) config_system_env ;;
    2) test_scripts_menu ;;
    3) fuqiang_menu ;;
    4) update_script ;; # 调用更新脚本函数
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。" ;;
  esac
done
