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

# 函数：配置系统环境子菜单
config_system_env() {
  while true; do
    clear_screen
    echo "配置系统环境："
    echo "1. 更新系统 (apt update && apt upgrade -y)"
    echo "2. 安装系统必要环境 (apt install unzip curl wget git sudo -y)"
    echo "3. 开启/配置 BBR 加速 (使用 tcpx.sh)"
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

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  while true; do
    clear_screen
    echo "测试脚本合集："
    echo "1. NodeQuality 测试 (bash <(curl -sL https://run.NodeQuality.com))"
    echo "2. IP 质量体检 (bash <(curl -sL IP.Check.Place))"
    echo "3. 融合怪测试 (bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh))"
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
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。" ;;
  esac
done
