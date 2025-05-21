#!/usr/bin/env bash

# 设置脚本在出错时立即退出
set -e

# 获取当前脚本的绝对路径
SCRIPT_PATH="$(readlink -f "$0")"

## 辅助函数定义

# 清空屏幕
clear_screen() {
  clear
}

# 检查是否以 root 身份运行
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "错误：请以 root 用户身份运行此脚本。"
    exit 1
  fi
}

# 检查是否为 OpenVZ 架构
ovz_no() {
  if [[ -d "/proc/vz" ]]; then
    echo "错误：您的VPS是OpenVZ架构，不支持此操作。"
    read -n 1 -s -p "按任意键返回菜单..."
    clear_screen
    return 1 # 表示检测到OVZ
  fi
  return 0 # 表示不是OVZ
}

## 配置系统环境功能 (主菜单选项 1)

# 开放所有端口
open_all_ports() {
  clear_screen
  check_root
  echo "正在尝试开放所有端口..."
  if command -v iptables >/dev/null 2>&1; then
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -F
    sudo rm -f /etc/iptables/rules.v4 /etc/iptables/rules.v6
    sudo systemctl stop ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
    sudo systemctl disable ufw firewalld iptables-persistent iptables-services 2>/dev/null || true
    echo "端口已全部开放。"
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
        echo "iptables 安装完成，端口已全部开放。"
      else
        echo "iptables 安装失败，无法开放端口。"
      fi
    else
      echo "取消开放所有端口。"
    fi
  fi
  read -n 1 -s -p "按任意键继续..."
  clear_screen
}

# 执行添加/设置swap的实际操作
perform_add_swap() {
  clear_screen
  echo "执行添加/设置swap虚拟内存..."

  ovz_no
  if [ $? -ne 0 ]; then
      return # ovz_no 已处理了提示和清屏
  fi

  echo "请输入需要设置的swap大小 (MB)，建议为内存的2倍！"
  read -p "请输入swap数值 (MB): " swapsize

  if ! [[ "$swapsize" =~ ^[0-9]+$ ]]; then
      echo "错误：请输入有效的数字！"
      read -n 1 -s -p "按任意键继续..."
      clear_screen
      return
  fi

  echo "正在检查并移除现有的 swapfile (如果存在)..."
  if grep -q "swapfile" /etc/fstab; then
      echo "检测到现有的 swapfile 配置，正在移除..."
      swapoff /swapfile 2>/dev/null || true
      sed -i '/swapfile/d' /etc/fstab
      rm -f /swapfile
      echo "现有的 swapfile 已删除。"
  else
      echo "未发现现有 swapfile 配置。"
  fi

  echo "正在创建大小为 ${swapsize}MB 的新 swapfile..."
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

  if [ ! -f /swapfile ]; then
      echo "错误：swapfile 创建失败！"
      read -n 1 -s -p "按任意键继续..."
      clear_screen
      return
  fi

  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab

  echo "新的 swapfile (${swapsize}MB) 已成功创建并启用。"
  echo "当前 swap 信息："
  cat /proc/swaps
  cat /proc/meminfo | grep Swap

  read -n 1 -s -p "按任意键继续..."
  clear_screen
}

# 执行删除swap的实际操作
perform_del_swap() {
  clear_screen
  echo "执行删除swap虚拟内存..."

  ovz_no
  if [ $? -ne 0 ]; then
      return # ovz_no 已处理了提示和清屏
  fi

  grep -q "swapfile" /etc/fstab

  if [ $? -eq 0 ]; then
      echo "swapfile已发现，正在将其移除..."
      swapoff /swapfile 2>/dev/null || true
      sed -i '/swapfile/d' /etc/fstab
      rm -f /swapfile
      echo "swap已删除！"
  else
      echo "swapfile未发现或未配置在 /etc/fstab 中，删除失败！"
  fi

  read -n 1 -s -p "按任意键继续..."
  clear_screen
}

# Swap 虚拟内存管理子菜单
swap_management_menu() {
    clear_screen
    check_root
    while true; do
        echo "Swap 虚拟内存管理："
        echo "------------------------"
        echo "1. 设置/添加 swap 虚拟内存"
        echo "2. 删除 swap 虚拟内存"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入指令数字并按 Enter 键: " swap_choice

        case "$swap_choice" in
            1) perform_add_swap ;;
            2) perform_del_swap ;;
            0) break ;;
            *)
                echo "无效的指令，请重新输入。"
                sleep 2
                clear_screen
                ;;
        esac
    done
}

# 使用 tcpx.sh 开启/配置 BBR 加速
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
  clear_screen
}

# 切换 IPv4/IPv6 优先子菜单
ipv4_ipv6_priority_menu() {
  clear_screen
  check_root
  while true; do
    clear_screen
    echo "设置 IPv4/IPv6 优先级"
    echo "------------------------"
    local ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)

    if [[ "$ipv6_disabled" == "1" ]]; then
      echo "当前临时优先级：IPv4（IPv6 当前禁用）"
    else
      echo "当前临时优先级：IPv6（IPv6 当前启用）"
    fi

    if [[ -f /etc/sysctl.d/99-disable-ipv6.conf ]]; then
      echo "检测到已配置永久禁用 IPv6（重启后仍禁用）"
    L
    else
      echo "未配置永久禁用 IPv6（重启后可能恢复启用）"
    fi

    echo ""
    echo "1. 切换为 IPv4 优先（临时）"
    echo "2. 切换为 IPv6 优先（临时）"
    echo "3. 永久禁用 IPv6（重启后保留）"
    echo "4. 恢复 IPv6 设置（启用并删除禁用配置）"
    echo "5. 查看当前网络优先状态"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -e -p "请选择操作: " choice

    case "$choice" in
      1)
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
        echo "已切换为 IPv4 优先（临时）"
        ;;
      2)
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
        echo "已切换为 IPv6 优先（临时）"
        ;;
      3)
        echo "正在永久禁用 IPv6..."
        cat <<EOF > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
        sysctl --system
        echo "IPv6 已永久禁用。建议重启系统以确保完全生效。"
        ;;
      4)
        echo "正在恢复 IPv6 设置..."
        rm -f /etc/sysctl.d/99-disable-ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
        sysctl --system
        echo "IPv6 设置已恢复（启用）。"
        ;;
      5)
        clear_screen
        echo "=== 当前 IPv6 状态 ==="
        echo "系统临时设置："
        sysctl net.ipv6.conf.all.disable_ipv6
        sysctl net.ipv6.conf.default.disable_ipv6
        echo ""
        echo "持久配置文件："
        if [[ -f /etc/sysctl.d/99-disable-ipv6.conf ]]; then
          echo "/etc/sysctl.d/99-disable-ipv6.conf 存在："
          cat /etc/sysctl.d/99-disable-ipv6.conf
        else
          echo "未发现持久禁用配置文件（IPv6 默认可启用）"
        fi
        echo "======================="
        ;;
      0)
        break
        ;;
      *)
        echo "无效输入，请重新选择。"
        ;;
    esac
    read -n 1 -s -p "按任意键继续..."
  done
}

# 配置系统环境子菜单
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
    echo "6. 添加/管理swap虚拟内存"
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
        clear_screen
        ;;
      2)
        echo "正在安装必要环境，请稍候..."
        sudo apt install unzip curl wget git sudo -y
        echo "必要环境安装完成。"
        read -n 1 -s -p "按任意键继续..."
        clear_screen
        ;;
      3) enable_bbr_with_tcpx ;;
      4) ipv4_ipv6_priority_menu ;;
      5) open_all_ports ;;
      6) swap_management_menu; clear_screen ;;
      9) break ;;
      0) echo "退出脚本。"; exit 0 ;;
      *) echo "无效的指令，请重新输入。" ;;
    esac
  done
}

## 测试脚本合集功能 (主菜单选项 2)

# 测试脚本合集子菜单
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
        read -p "确定要运行 NodeQuality 测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen
          echo "正在运行 NodeQuality 测试脚本，请稍候..."
          bash <(curl -sL https://run.NodeQuality.com)
          echo "NodeQuality 测试完成。脚本将退出。"
          exit 0
        else
          clear_screen
        fi
        ;;
      2)
        read -p "确定要运行 IP 质量体检吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen
          echo "正在运行 IP 质量体检脚本，请稍候..."
          bash <(curl -sL IP.Check.Place)
          echo "IP 质量体检完成。脚本将退出。"
          exit 0
        else
          clear_screen
        fi
        ;;
      3)
        read -p "确定要运行 融合怪测试吗？ (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          clear_screen
          echo "正在运行 融合怪测试脚本，请稍候..."
          bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
          echo "融合怪测试完成。脚本将退出。"
          exit 0
        else
          clear_screen
        fi
        ;;
      9) break ;;
      0) echo "退出脚本。"; exit 0 ;;
      *) echo "无效的指令，请重新输入。" ;;
    esac
  done
}

## 富强专用功能 (主菜单选项 3)

# 富强专用子菜单
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
        clear_screen
        echo "正在安装 3x-ui 面板，请稍候..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        echo "3x-ui 面板安装完成。脚本将退出。"
        exit 0
        ;;
      2)
        clear_screen
        echo "正在安装八合一脚本，请稍候..."
        wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
        echo "八合一脚本安装完成。脚本将退出。"
        exit 0
        ;;
      3)
        clear_screen
        echo "正在安装 snell，请稍候..."
        wget https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -O snell.sh && chmod +x snell.sh && ./snell.sh
        echo "snell 安装完成。脚本将退出。"
        exit 0
        ;;
      4)
        clear_screen
        echo "正在安装 realm & gost 一键转发脚本，请稍候..."
        wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh
        echo "realm & gost 一键转发脚本安装完成。脚本将退出。"
        exit 0
        ;;
      0) break ;;
      *) echo "无效的指令，请重新输入。" ;;
    esac
  done
}

## 建站工具功能 (主菜单选项 4)
# Caddy 反向代理工具函数 (内部函数均加 `_caddy_` 前缀避免冲突)
_caddy_check_installed() {
    if command -v caddy >/dev/null 2>&1; then return 0; else return 1; fi
}
_caddy_install() {
    echo "开始安装 Caddy..."
    sudo apt-get update
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt-get update
    sudo apt-get install -y caddy
    if _caddy_check_installed; then echo "Caddy 安装成功！"; else echo "Caddy 安装失败，请检查日志。"; return 1; fi
}
_caddy_check_port_running() {
    local port=$1
    if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then echo "运行中"; else echo "未运行"; fi
}
_caddy_setup_reverse_proxy() {
    echo "请输入域名（例如 example.com）："; read domain
    if [ -z "$domain" ]; then echo "域名输入不能为空。"; return; fi
    echo "请输入上游服务端口（例如 8080）："; read port
    if [ -z "$port" ]; then echo "端口输入不能为空。"; return; fi
    local upstream="http://127.0.0.1:${port}"
    local CADDYFILE="/etc/caddy/Caddyfile"
    local BACKUP_CADDYFILE="${CADDYFILE}.bak"
    local PROXY_CONFIG_FILE="/root/caddy_reverse_proxies.txt"

    if [ ! -f "$BACKUP_CADDYFILE" ]; then sudo cp "$CADDYFILE" "$BACKUP_CADDYFILE"; fi
    if grep -qE "^${domain}\s?{" "$CADDYFILE"; then
        echo "警告：Caddyfile 中已存在域名 '${domain}' 的配置。此操作将追加新的配置，可能导致冲突。"
        echo "建议手动编辑 Caddyfile 或使用删除功能后再重新添加。"; read -n 1 -s -p "按任意键继续（或按 Ctrl+C 中止）..."
    fi
    echo "配置反向代理：${domain} -> ${upstream}"
    echo "${domain} {
    reverse_proxy ${upstream}
}" | sudo tee -a "$CADDYFILE" >/dev/null
    echo "${domain} -> ${upstream}" >> "$PROXY_CONFIG_FILE"
    echo "正在重启 Caddy 服务以应用新配置..."; sudo systemctl restart caddy
    local status=$(_caddy_check_port_running "$port")
    echo "上游服务（127.0.0.1:${port}）状态：$status"; echo "Caddy 服务状态："; sudo systemctl status caddy --no-pager
}
_caddy_show_status() {
    if _caddy_check_installed; then echo "Caddy 服务状态："; sudo systemctl status caddy --no-pager; else echo "系统中未安装 Caddy。"; fi
}
_caddy_show_proxies() {
    local PROXY_CONFIG_FILE="/root/caddy_reverse_proxies.txt"
    if [ -f "$PROXY_CONFIG_FILE" ]; then
        echo "当前反向代理配置："
        local lineno=0
        while IFS= read -r line; do
            lineno=$((lineno+1))
            local port=$(echo "$line" | grep -oE '[0-9]{2,5}$')
            local status=$(_caddy_check_port_running "$port")
            echo "${lineno}) ${line} [上游服务状态：$status]"
        done < "$PROXY_CONFIG_FILE"
    else
        echo "没有配置任何反向代理。"
    fi
}
_caddy_delete_proxy() {
    local CADDYFILE="/etc/caddy/Caddyfile"
    local PROXY_CONFIG_FILE="/root/caddy_reverse_proxies.txt"
    _caddy_show_proxies
    echo "请输入要删除的反向代理配置编号："; read proxy_number
    if [ -z "$proxy_number" ]; then echo "无效的输入。"; return; fi
    if ! [[ "$proxy_number" =~ ^[0-9]+$ ]]; then echo "错误：请输入有效的数字！"; return; fi
    local proxy_to_delete=$(sed -n "${proxy_number}p" "$PROXY_CONFIG_FILE")
    if [ -z "$proxy_to_delete" ]; then echo "错误：无效的编号，该配置不存在。"; return; fi
    local domain_to_delete=$(echo "$proxy_to_delete" | awk -F' -> ' '{print $1}')
    sed -i "${proxy_number}d" "$PROXY_CONFIG_FILE"
    echo "已从代理列表文件移除：${proxy_to_delete}"
    echo "正在从 Caddyfile 中删除域名 '${domain_to_delete}' 相关的配置块..."
    sudo awk -v d="${domain_to_delete}" '
        !match($0, d " \\{") { print }
        match($0, d " \\{") { skip = 1; print; next }
        /}/ && skip { skip = 0; next }
        !skip { print }
    ' "$CADDYFILE" > "${CADDYFILE}.tmp" && sudo mv "${CADDYFILE}.tmp" "$CADDYFILE"
    echo "重启 Caddy 服务..."; sudo systemctl restart caddy
    echo "反向代理删除成功！"
}
_caddy_restart() {
    echo "正在重启 Caddy 服务..."; sudo systemctl restart caddy
    echo "Caddy 服务已重启。"; sudo systemctl status caddy --no-pager
}
_caddy_remove() {
    echo "确定要卸载 Caddy 并删除配置文件吗？(y/n)"; read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo systemctl stop caddy; sudo apt-get remove --purge -y caddy
        sudo rm -f /etc/apt/sources.list.d/caddy-stable.list; sudo apt-get update
        local CADDYFILE="/etc/caddy/Caddyfile"
        local BACKUP_CADDYFILE="${CADDYFILE}.bak"
        local PROXY_CONFIG_FILE="/root/caddy_reverse_proxies.txt"
        if [ -f "$BACKUP_CADDYFILE" ]; then sudo rm -f "$CADDYFILE" "$BACKUP_CADDYFILE"; else sudo rm -f "$CADDYFILE"; fi
        if [ -f "$PROXY_CONFIG_FILE" ]; then sudo rm -f "$PROXY_CONFIG_FILE"; fi
        echo "Caddy 已卸载并删除配置文件。"
    else
        echo "操作已取消。"
    fi
}
_caddy_show_menu() {
    echo "============================================="
    local caddy_status=$(systemctl is-active caddy 2>/dev/null)
    if [ "$caddy_status" == "active" ]; then echo "Caddy 状态：运行中"; else echo "Caddy 状态：未运行"; fi
    echo "          Caddy 一键部署 & 管理脚本（来自Hlonglin）         "
    echo "============================================="
    echo " 1) 安装 Caddy（如已安装则跳过）"
    echo " 2) 配置 & 启用反向代理（输入域名及上游端口）"
    echo " 3) 查看 Caddy 服务状态"
    echo " 4) 查看当前反向代理配置（显示上游服务状态）"
    echo " 5) 删除指定的反向代理"
    echo " 6) 重启 Caddy 服务"
    echo " 7) 卸载 Caddy（删除配置）"
    echo " 0) 返回上一级菜单"
    echo "============================================="
}

caddy_proxy_tool() {
  while true; do
      _caddy_show_menu
      read -p "请输入选项: " opt
      case "$opt" in
          1) if _caddy_check_installed; then echo "Caddy 已安装，跳过安装。"; else _caddy_install || continue; fi ;;
          2) if ! _caddy_check_installed; then echo "Caddy 未安装，先执行安装步骤。"; _caddy_install || continue; fi; _caddy_setup_reverse_proxy ;;
          3) _caddy_show_status ;;
          4) _caddy_show_proxies ;;
          5) _caddy_delete_proxy ;;
          6) _caddy_restart ;;
          7) _caddy_remove ;;
          0) echo "返回上一级菜单。"; break ;;
          *) echo "无效选项，请重新输入。" ;;
      esac
      echo
  done
}

website_tools_menu() {
    clear_screen
    check_root
    while true; do
        echo "建站工具："
        echo "1. 安装 1Panel 面板"
        echo "2. 一键配置 Caddy 反代"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入指令数字并按 Enter 键: " sub_choice_web
        case "$sub_choice_web" in
            1)
                clear_screen
                echo "正在安装 1Panel 面板，请稍候..."
                curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh
                echo "1Panel 面板安装完成。"
                read -n 1 -s -p "按任意键继续..."
                clear_screen
                ;;
            2)
                clear_screen
                caddy_proxy_tool
                read -n 1 -s -p "按任意键继续..."
                clear_screen
                ;;
            0) break ;;
            *) echo "无效的指令，请重新输入。"; sleep 2; clear_screen ;;
        esac
    done
}

## 脚本更新功能 (主菜单选项 9)
update_script() {
  clear_screen
  echo "正在检查并更新脚本..."
  GITHUB_RAW_URL="https://raw.githubusercontent.com/s0meones/Shortcuts/main/shell.sh"
  temp_file=$(mktemp)
  if wget -O "$temp_file" "$GITHUB_RAW_URL"; then
    echo "脚本下载成功！"
    if mv "$temp_file" "$SCRIPT_PATH"; then
      chmod +x "$SCRIPT_PATH"
      echo "脚本更新成功！正在启动新版本脚本..."
      exec "$SCRIPT_PATH"
    else
      echo "错误：脚本更新失败！无法替换原文件 '$SCRIPT_PATH'。"
      echo "请检查文件权限或目标路径是否存在问题。"
      rm -f "$temp_file"
    fi
  else
    echo "错误：脚本下载失败！请检查网络连接或 GitHub Raw URL 是否正确。"
  fi
  read -n 1 -s -p "按任意键返回主菜单..."
  clear_screen
}

## 主菜单显示函数
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
  echo "4. 建站工具"
  echo "9. 更新脚本"
  echo "0. 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}


## 脚本初始化和主程序逻辑

# 检查是否以 root 身份运行
check_root

# 首次运行检测与自动安装 's' 命令逻辑
LINK_PATH="/usr/local/bin/s"
INSTALL_MARKER="/etc/s_command_installed"

if [ ! -f "$INSTALL_MARKER" ] && [ "$EUID" -eq 0 ]; then
    clear_screen
    echo "欢迎使用此脚本！"
    echo "检测到脚本尚未安装为 's' 命令全局调用。"
    echo "此操作将在 '$LINK_PATH' 位置创建一个符号链接指向脚本 '$SCRIPT_PATH'。"
    echo ""
    read -p "是否立即安装到 '$LINK_PATH' 并启用 's' 命令？ (y/N): " auto_install_confirm

    if [[ "$auto_install_confirm" == "y" || "$auto_install_confirm" == "Y" ]]; then
        echo "正在安装..."
        if [ -f "$LINK_PATH" ] || [ -L "$LINK_PATH" ]; then
            echo "检测到目标路径 '$LINK_PATH' 已存在，正在尝试覆盖..."
            sudo rm -f "$LINK_PATH"
        fi
        echo "正在创建新的符号链接 '$LINK_PATH' -> '$SCRIPT_PATH'..."
        if sudo ln -s "$SCRIPT_PATH" "$LINK_PATH"; then
            echo "安装成功！您现在可以使用 's' 命令启动脚本了。"
            echo "注意：您可能需要关闭并重新打开终端使命令生效。"
            sudo touch "$INSTALL_MARKER"
        else
            echo "错误：安装失败！请检查是否有写入 '$LINK_PATH' 目录的权限或目标路径是否存在问题。"
        fi
        read -n 1 -s -p "按任意键继续进入主菜单..."
        clear_screen
    else
        echo "已取消自动安装为 's' 命令。您仍然可以通过完整路径 '$SCRIPT_PATH' 或 './' 方式运行脚本。"
        read -n 1 -s -p "按任意键继续进入主菜单..."
        clear_screen
    fi
fi

# 主循环：显示主菜单并处理用户输入
while true; do
  show_main_menu
  case "$main_choice" in
    1) config_system_env ;;
    2) test_scripts_menu ;;
    3) fuqiang_menu ;;
    4) website_tools_menu ;;
    9) update_script ;;
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效的指令，请重新输入。" ;;
  esac
done
