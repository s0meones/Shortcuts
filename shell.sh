#!/usr/bin/env bash

# 设置脚本在出错时立即退出
set -e

# 获取当前脚本的绝对路径
SCRIPT_PATH="$(readlink -f "$0")"

# 函数：清空屏幕
clear_screen() {
  clear
}

# 函数：检查是否以 root 身份运行
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "错误：请以 root 用户身份运行此脚本。"
    exit 1
  fi
}

# 函数：检查是否为 OpenVZ 架构 (不带颜色)
ovz_no() {
  if [[ -d "/proc/vz" ]]; then
    echo "错误：您的VPS是OpenVZ架构，不支持此操作。"
    read -n 1 -s -p "按任意键返回菜单..."
    clear_screen
    return 1 # Indicate OVZ detected
  fi
  return 0 # Indicate not OVZ
}


# 函数：发送统计信息 (占位符)
send_stats() {
  echo "统计: $1"
}

# 函数：开放所有端口
open_all_ports() {
  clear_screen
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
  clear_screen # 添加清屏
}

# 函数：执行添加/设置swap的实际操作 (不带颜色)
perform_add_swap() {
  clear_screen
  echo "执行添加/设置swap虚拟内存..." # 更新提示信息

  # 检查是否为OVZ，如果是则返回
  ovz_no
  if [ $? -ne 0 ]; then
      # ovz_no 已经处理了提示、暂停和清屏
      return
  fi

  echo "请输入需要设置的swap大小 (MB)，建议为内存的2倍！" # 更新提示信息
  read -p "请输入swap数值 (MB): " swapsize

  # 检查是否为有效数字
  if ! [[ "$swapsize" =~ ^[0-9]+$ ]]; then
      echo "错误：请输入有效的数字！"
      read -n 1 -s -p "按任意键继续..."
      clear_screen
      return
  fi

  # --- 开始：检查并移除现有的 /swapfile ---
  echo "正在检查并移除现有的 swapfile (如果存在)..."
  # 检查 /etc/fstab 中是否有 /swapfile 这一行
  if grep -q "swapfile" /etc/fstab; then
      echo "检测到现有的 swapfile 配置，正在移除..."
      # 尝试先关闭 swapfile
      swapoff /swapfile 2>/dev/null || true # 忽略错误如果它未激活
      # 从 fstab 中删除该行
      sed -i '/swapfile/d' /etc/fstab
      # 删除 swap 文件
      rm -f /swapfile
      echo "现有的 swapfile 已删除。"
  else
      echo "未发现现有 swapfile 配置。"
  fi
  # --- 结束：检查并移除现有的 /swapfile ---


  # --- 开始：创建新的 swapfile ---
  echo "正在创建大小为 ${swapsize}MB 的新 swapfile..."
  # 检查创建文件命令并使用
  if command -v fallocate >/dev/null 2>&1; then
      fallocate -l ${swapsize}M /swapfile
  elif command -v dd >/dev/null 2>&1; then
       dd if=/dev/zero of=/swapfile bs=1M count=${swapsize}
  else
      echo "错误：找不到 fallocate 或 dd 命令，无法创建 swap 文件。"
      read -n 1 -s -p "按任意键继续..."
      clear_screen
      return
  fi

  # 检查文件是否成功创建
  if [ ! -f /swapfile ]; then
      echo "错误：swapfile 创建失败！"
      read -n 1 -s -p "按任意键继续..."
      clear_screen
      return
  fi

  # 设置文件权限，格式化并启用
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  # 添加到 fstab 使其开机自启动
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab

  echo "新的 swapfile (${swapsize}MB) 已成功创建并启用。"
  echo "当前 swap 信息："
  cat /proc/swaps
  cat /proc/meminfo | grep Swap
  # --- 结束：创建新的 swapfile ---

  read -n 1 -s -p "按任意键继续..."
  clear_screen # 清屏
}

# 函数：执行删除swap的实际操作 (不带颜色)
perform_del_swap() {
  clear_screen
  echo "执行删除swap虚拟内存..."

   # 检查是否为OVZ，如果是则返回
  ovz_no
  if [ $? -ne 0 ]; then
      # ovz_no 已经处理了提示、暂停和清屏
      return
  fi

  #检查是否存在swapfile 在 /etc/fstab 中
  grep -q "swapfile" /etc/fstab

  #如果存在就将其移除
  if [ $? -eq 0 ]; then
      echo "swapfile已发现，正在将其移除..."
      # 尝试关闭 swapfile
      swapoff /swapfile 2>/dev/null || true # 忽略错误如果它未激活
      # 从 fstab 中删除该行
      sed -i '/swapfile/d' /etc/fstab
      # 清除 pagecache, dentries and inodes (可选，但通常用于释放内存)
      # echo "3" > /proc/sys/vm/drop_caches # 谨慎使用此命令
      # 删除 swap 文件
      rm -f /swapfile
      echo "swap已删除！"
  else
      echo "swapfile未发现或未配置在 /etc/fstab 中，删除失败！" # 更新提示
  fi

  read -n 1 -s -p "按任意键继续..."
  clear_screen # 清屏
}

# 函数：Swap 虚拟内存管理子菜单
swap_management_menu() {
    clear_screen
    check_root
    while true; do
        echo "Swap 虚拟内存管理："
        echo "------------------------"
        echo "1. 设置/添加 swap 虚拟内存" # 更新菜单名称
        echo "2. 删除 swap 虚拟内存"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入指令数字并按 Enter 键: " swap_choice

        case "$swap_choice" in
            1)
                perform_add_swap # 实际执行设置/添加操作
                # perform_add_swap 函数内部已处理清屏和暂停
                ;;
            2)
                perform_del_swap # 实际执行删除操作
                # perform_del_swap 函数内部已处理清屏和暂停
                ;;
            0)
                break # 返回配置系统环境菜单
                ;;
            *)
                echo "无效的指令，请重新输入。"
                sleep 2
                clear_screen # 清屏
                ;;
        esac
    done
}


# 函数：配置系统环境子菜单
config_system_env() {
  clear_screen
  check_root
  while true; do
    echo "配置系统环境："
    echo "1. 更新系统"
    echo "2. 安装系统必要环境 unzip curl wget git sudo -"
    echo "3. 开启/配置 BBR 加速"
    echo "4. 切换 IPv4/IPv6 优先"
    echo "5. 开放所有端口"
    echo "6. 添加/管理swap虚拟内存" # 添加新选项
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
        clear_screen # 添加清屏
        ;;
      2)
        echo "正在安装必要环境，请稍候..."
        sudo apt install unzip curl wget git sudo -y
        echo "必要环境安装完成。"
        read -n 1 -s -p "按任意键继续..."
        clear_screen # 添加清屏
        ;;
      3)
        enable_bbr_with_tcpx
        # enable_bbr_with_tcpx 函数内部已处理清屏
        ;;
      4)
        ipv4_ipv6_priority_menu
        # ipv4_ipv6_priority_menu 函数内部已处理清屏
        clear_screen # 从子菜单返回后清屏
        ;;
      5)
        open_all_ports
        # open_all_ports 函数内部已处理清屏
        ;;
      6) # 处理新选项
        swap_management_menu
        clear_screen # 从swap管理菜单返回后清屏
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
        # 无效指令的提示后，不暂停，直接进入下一轮循环，下一轮循环会先清屏，无需在此添加清屏
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
  clear_screen # 添加清屏
}

# 函数：切换 IPv4/IPv6 优先子菜单 (被 config_system_env 调用)
ipv4_ipv6_priority_menu() {
  clear_screen
  check_root
  send_stats "设置v4/v6优先级"
  while true; do
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
    echo "1. IPv4 优先           2. IPv6 优先           3. IPv6 修复工具"
    echo "------------------------"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -e -p "选择优先的网络: " choice

    case $choice in
      1)
        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
        echo "已切换为 IPv4 优先"
        send_stats "已切换为 IPv4 优先"
        read -n 1 -s -p "按任意键继续..." # 添加暂停
        clear_screen # 添加清屏
        ;;
      2)
        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
        echo "已切换为 IPv6 优先"
        send_stats "已切换为 IPv6 优先"
        read -n 1 -s -p "按任意键继续..." # 添加暂停
        clear_screen # 添加清屏
        ;;

      3)
        clear_screen # 调用外部脚本前先清屏，保持界面整洁
        bash <(curl -L -s jhb.ovh/jb/v6.sh)
        echo "该功能由jhb大神提供，感谢他！"
        send_stats "ipv6修复"
        read -n 1 -s -p "按任意键返回 v4/v6 优先级菜单..."
        clear_screen # 添加清屏
        ;;

      0)
        break
        ;;

      *)
        echo "无效的选择，请重新输入。"
        sleep 2
        clear_screen # 添加清屏
        ;;

    esac
  done
}

# 函数：测试脚本合集子菜单
test_scripts_menu() {
  clear_screen
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
        echo ""
        read -p "确定要运行 NodeQuality 测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen # 调用外部脚本前先清屏
          echo "正在运行 NodeQuality 测试脚本，请稍候..."
          bash <(curl -sL https://run.NodeQuality.com)
          echo "NodeQuality 测试完成。"
          # 移除暂停和清屏，直接退出脚本
          exit 0
        else
          clear_screen # 如果取消，清屏并重新显示菜单
        fi
        ;; # 注意：这里移除了 ;; 因为上面有 exit
      2)
        echo ""
        read -p "确定要运行 IP 质量体检吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen # 调用外部脚本前先清屏
          echo "正在运行 IP 质量体检脚本，请稍候..."
          bash <(curl -sL IP.Check.Place)
          echo "IP 质量体检完成。"
          # 移除暂停和清屏，直接退出脚本
          exit 0
        else
          clear_screen # 如果取消，清屏并重新显示菜单
        fi
        ;; # 注意：这里移除了 ;; 因为上面有 exit
      3)
        echo ""
        read -p "确定要运行 融合怪测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen # 调用外部脚本前先清屏
          echo "正在运行 融合怪测试脚本，请稍候..."
          bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
          echo "融合怪测试完成。"
          # 移除暂停和清屏，直接退出脚本
          exit 0
        else
          clear_screen # 如果取消，清屏并重新显示菜单
        fi
        ;; # 注意：这里移除了 ;; 因为上面有 exit
      9)
        break # 返回主菜单
        ;;
      0)
        echo "退出脚本。"
        exit 0
        ;;
      *)
        echo "无效的指令，请重新输入。"
        # 无效指令的提示后，不暂停，直接进入下一轮循环，下一轮循环会先清屏，无需在此添加清屏
        ;;
    esac
  done
}

# 函数：富强专用子菜单
fuqiang_menu() {
  clear_screen
  while true; do
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
        clear_screen # 调用外部脚本前先清屏
        echo "正在安装 3x-ui 面板，请稍候..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        echo "3x-ui 面板安装完成。"
        echo "操作已完成，脚本即将结束。"
        # 这里是退出脚本，不需要清屏和返回菜单
        exit 0
        ;;
      2)
        clear_screen # 调用外部脚本前先清屏
        echo "正在安装八合一脚本，请稍候..."
        wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
        echo "八合一脚本安装完成。"
        echo "操作已完成，脚本即将结束。"
        # 这里是退出脚本，不需要清屏和返回菜单
        exit 0
        ;;
      3)
        clear_screen # 调用外部脚本前先清屏
        echo "正在安装 snell，请稍候..."
        wget https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -O snell.sh && chmod +x snell.sh && ./snell.sh
        echo "snell 安装完成。"
        echo "操作已完成，脚本即将结束。"
        # 这里是退出脚本，不需要清屏和返回菜单
        exit 0
        ;;
      4)
        clear_screen # 调用外部脚本前先清屏
        echo "正在安装 realm & gost 一键转发脚本，请稍候..."
        wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh
        echo "realm & gost 一键转发脚本安装完成。"
        echo "操作已完成，脚本即将结束。"
        # 这里是退出脚本，不需要清屏和返回菜单
        exit 0
        ;;
      0)
        break # 返回主菜单
        ;;
      *)
        echo "无效的指令，请重新输入。"
        # 无效指令的提示后，不暂停，直接进入下一轮循环，下一轮循环会先清屏，无需在此添加清屏
        ;;
    esac
  done
}

# 函数：更新脚本
update_script() {
  clear_screen
  echo "正在检查并更新脚本..."

  # *** 已替换为您的 GitHub Raw URL ***
  GITHUB_RAW_URL="https://raw.githubusercontent.com/s0meones/Shortcuts/main/shell.sh"
  # ***********************************

  # 创建一个临时文件来存放下载的新脚本
  temp_file=$(mktemp)

  # 下载最新脚本
  if wget -O "$temp_file" "$GITHUB_RAW_URL"; then
    echo "脚本下载成功！"

    # 替换当前脚本文件
    if mv "$temp_file" "$SCRIPT_PATH"; then
      # 添加执行权限
      chmod +x "$SCRIPT_PATH"
      echo "脚本更新成功！正在启动新版本脚本..."
      # 使用 exec 替换当前进程为新脚本进程
      exec "$SCRIPT_PATH"
    else
      echo "错误：脚本更新失败！无法替换原文件 '$SCRIPT_PATH'。"
      echo "请检查文件权限或目标路径是否存在问题。"
      rm -f "$temp_file" # 清理临时文件
    fi
  else
    echo "错误：脚本下载失败！请检查网络连接或 GitHub Raw URL 是否正确。"
    # 下载失败不需要清理临时文件，因为wget可能没有创建它，即使创建了也让它留在/tmp里
  fi

  # 如果更新失败，暂停并返回主菜单
  read -n 1 -s -p "按任意键返回主菜单..."
  clear_screen # 添加清屏
}


# --- 首次运行检测与自动安装s命令逻辑 ---

# 定义s命令的目标安装路径和标记文件
LINK_PATH="/usr/local/bin/s"
INSTALL_MARKER="/etc/s_command_installed" # 用于标记是否已安装过s命令

# 在检查root权限后执行此逻辑
check_root

# 检查是否尚未安装s命令标记文件 并且 当前是root用户
# 注意：这里简化检查，如果标记文件不存在，就认为是首次需要安装
if [ ! -f "$INSTALL_MARKER" ] && [ "$EUID" -eq 0 ]; then
    clear_screen
    echo "欢迎使用此脚本！"
    echo "检测到脚本尚未安装为 's' 命令全局调用。"
    echo "此操作将在 '$LINK_PATH' 位置创建一个符号链接指向脚本 '$SCRIPT_PATH'。"
    echo ""
    read -p "是否立即安装到 '$LINK_PATH' 并启用 's' 命令？ (y/N): " auto_install_confirm

    if [[ "$auto_install_confirm" == "y" || "$auto_install_confirm" == "Y" ]]; then
        # 执行安装逻辑 (与 install_s_command 函数内容类似)
        echo "正在安装..."

        # 检查目标路径是否已存在文件或链接，并尝试覆盖
        if [ -f "$LINK_PATH" ] || [ -L "$LINK_PATH" ]; then
            echo "检测到目标路径 '$LINK_PATH' 已存在，正在尝试覆盖..."
            sudo rm -f "$LINK_PATH" # 使用 sudo 确保权限
        fi

        # 创建符号链接
        echo "正在创建新的符号链接 '$LINK_PATH' -> '$SCRIPT_PATH'..."
        if sudo ln -s "$SCRIPT_PATH" "$LINK_PATH"; then # 使用 sudo 确保权限
            echo "安装成功！您现在可以使用 's' 命令启动脚本了。"
            echo "注意：您可能需要关闭并重新打开终端使命令生效。"
            sudo touch "$INSTALL_MARKER" # 安装成功后创建标记文件
        else
            echo "错误：安装失败！请检查是否有写入 '$LINK_PATH' 目录的权限或目标路径是否存在问题。"
        fi

        # 暂停，让用户看清楚安装结果
        read -n 1 -s -p "按任意键继续进入主菜单..."
        clear_screen # 清屏后进入主菜单

    else # 用户取消安装
        echo "已取消自动安装为 's' 命令。您仍然可以通过完整路径 '$SCRIPT_PATH' 或 './' 方式运行脚本。"
        # 暂停，让用户看清楚取消信息
        read -n 1 -s -p "按任意键继续进入主菜单..."
        clear_screen # 清屏后进入主菜单
    fi
fi
# --- 首次运行检测与自动安装s命令逻辑结束 ---


# 函数：显示主菜单 (已移除安装 s 命令选项)
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
  # 原来的 8. 安装 s 命令快速启动 已移除，首次运行已处理
  echo "9. 更新脚本"
  echo "0. 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}


# 主循环 (已移除处理选项 8 的 case)
while true; do
  show_main_menu
  case "$main_choice" in
    1) config_system_env ;;
    2) test_scripts_menu ;;
    3) fuqiang_menu ;;
    # 原来的 8) install_s_command ;; 已移除，逻辑已前置
    9) update_script ;;
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。"
       # 无效指令的提示后，不暂停，直接进入下一轮循环，下一轮循环会先清屏，无需在此添加清屏
       ;;
  esac
done
