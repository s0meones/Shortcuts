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
  echo "3. 富强专用"
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

# 函数：添加虚拟内存
add_swap() {
  check_root
  local size_mb="$1"
  local swap_file="/swapfile"

  if [ -e "$swap_file" ]; then
    echo -e "\n警告：文件 ${swap_file} 已存在。"
    read -p "是否覆盖现有文件？ (y/N，警告：如果当前是活动的 swap，可能会导致问题): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      read -p "请输入新的交换文件名 (例如 /swapfile2): " new_swap_file
      if [ -z "$new_swap_file" ]; then
        echo "操作取消。"
        read -n 1 -s -p "按任意键继续..."
        return 1
      else
        swap_file="$new_swap_file"
      fi
    fi
  fi

  echo "开始创建 ${size_mb}MB 的虚拟内存文件: ${swap_file}..."
  sudo fallocate -l "${size_mb}M" "$swap_file"
  if [ $? -ne 0 ]; then
    echo "创建交换文件失败。"
    read -n 1 -s -p "按任意键继续..."
    return 1
  fi
  sudo chmod 600 "$swap_file"
  sudo mkswap "$swap_file"
  if [ $? -ne 0 ]; then
    echo "设置交换文件失败。"
    read -n 1 -s -p "按任意键继续..."
    return 1
  fi
  sudo swapon "$swap_file"
  if [ $? -ne 0 ]; then
    echo "启用交换文件失败。"
    read -n 1 -s -p "按任意键继续..."
    return 1
  fi
  echo "${swap_file} swap swap defaults 0 0" | sudo tee -a /etc/fstab
  echo "成功设置 ${size_mb}MB 虚拟内存。"
  read -n 1 -s -p "按任意键继续..."
}

# 函数：开放所有端口
open_all_ports() {
  check_root
  send_stats "开放端口"
  if command -v iptables >/dev/null 2>&1; then
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -F
    sudo rm -f /etc/iptables/rules.v4 /etc/iptables/rules.v6
    sudo systemctl stop ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
    sudo systemctl disable ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
    echo "端口已全部开放"
  else
    read -p "iptables 命令未找到，是否安装？ (y/N): " install_iptables
    if [[ "$install_iptables" == "y" || "$install_iptables" == "Y" ]]; then
      echo "正在安装 iptables..."
      sudo apt update
      sudo apt install -y iptables
      if command -v iptables >/dev/null 2>&1; then
        sudo iptables -P INPUT ACCEPT
        sudo iptables -P FORWARD ACCEPT
        sudo iptables -P OUTPUT ACCEPT
        sudo iptables -F
        sudo rm -f /etc/iptables/rules.v4 /etc/iptables/rules.v6
        sudo systemctl stop ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
        sudo systemctl disable ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
        echo "iptables 安装完成，端口已全部开放"
      else
        echo "iptables 安装失败，无法开放端口。"
      fi
    else
      echo "取消开放所有端口。"
    fi
  fi
  read -n 1 -s -p "按任意键继续..."
}

# 函数：设置虚拟内存子菜单
set_swap() {
  check_root
  send_stats "设置虚拟内存"
  while true; do
    clear_screen
    echo "设置虚拟内存"
    local swap_used=$(free -m | awk 'NR==3{print $3}')
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')

    echo "当前虚拟内存: $swap_info"
    echo "------------------------"
    echo "1. 分配1024M          2. 分配2048M          3. 分配4096M          4. 自定义大小"
    echo "------------------------"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -e -p "请输入你的选择: " choice

    case "$choice" in
      1)
        send_stats "已设置1G虚拟内存"
        add_swap 1024
        ;;
      2)
        send_stats "已设置2G虚拟内存"
        add_swap 2048
        ;;
      3)
        send_stats "已设置4G虚拟内存"
        add_swap 4096
        ;;
      4)
        read -e -p "请输入虚拟内存大小（单位M）: " new_swap
        add_swap "$new_swap"
        send_stats "已设置自定义虚拟内存"
        ;;
      0)
        break
        ;;
      *)
        echo "无效的选择，请重新输入。"
        ;;
    esac
  done
}

# 函数：配置系统环境子菜单
config_system_env() {
  check_root
  while true; do
    clear_screen
    echo "配置系统环境："
    echo "1. 更新系统"
    echo "2. 安装系统必要环境 unzip curl wget git sudo -"
    echo "3. 开启/配置 BBR 加速"
    echo "4. 切换 IPv4/IPv6 优先"
    echo "5. 开放所有端口"
    echo "6. 设置虚拟内存"
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
      5)
        open_all_ports
        ;;
      6)
        set_swap
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
        read -p "确定要运行 NodeQuality 测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          echo "正在运行 NodeQuality 测试脚本，请稍候..."
          bash <(curl -sL https://run.NodeQuality.com)
          echo "NodeQuality 测试完成。"
          read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
        fi
        ;;
      2)
        read -p "确定要运行 IP 质量体检吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          echo "正在运行 IP 质量体检脚本，请稍候..."
          bash <(curl -sL IP.Check.Place)
          echo "IP 质量体检完成。"
          read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
        fi
        ;;
      3)
        read -p "确定要运行 融合怪测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          echo "正在运行 融合怪测试脚本，请稍候..."
          bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
          echo "融合怪测试完成。"
          read -n 1 -s -p "按任意键返回测试脚本合集菜单..."
        fi
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
    echo "0. 返回主菜单"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice_fq
    case "$sub_choice_fq" in
      1)
        echo "正在安装 3x-ui 面板，请稍候..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        echo "3x-ui 面板安装完成。"
        echo "操作已完成，脚本即将结束。"
        exit 0
        ;;
      2)
        echo "正在安装八合一脚本，请稍候..."
        wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
        echo "八合一脚本安装完成。"
        echo "操作已完成，脚本即将结束。"
        exit 0
        ;;
      3)
        echo "正在安装 snell，请稍候..."
        wget https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -O snell.sh && chmod +x snell.sh && ./snell.sh
        echo "snell 安装完成。"
        echo "操作已完成，脚本即将结束。"
        exit 0
        ;;
      4)
        echo "正在安装 realm & gost 一键转发脚本，请稍候..."
        wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh
        echo "realm & gost 一键转发脚本安装完成。"
        echo "操作已完成，脚本即将结束。"
        exit 0
        ;;
      0)
        break # 返回主菜单
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
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。" ;;
  esac
done
