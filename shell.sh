#!/bin/bash

# 设置脚本在出错时立即退出
set -e

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "             <span class="math-inline">\{GREEN\}Debian 12 一键配置交互式脚本</span>{NC}               "
echo "                           作者：s0meones                           "
echo ""

# 函数：显示主菜单
show_main_menu() {
  echo ""
  echo "<span class="math-inline">\{YELLOW\}请选择要执行的操作：</span>{NC}"
  echo "<span class="math-inline">\{BLUE\}1\.</span>{NC} 配置系统环境"
  echo "<span class="math-inline">\{BLUE\}2\.</span>{NC} 测试脚本合集"
  echo "<span class="math-inline">\{BLUE\}3\.</span>{NC} 更新本脚本"
  echo "<span class="math-inline">\{BLUE\}0\.</span>{NC} 退出脚本"
  echo ""
  read -p "请输入指令数字并按 Enter 键: " main_choice
}

# 函数：更新本脚本
update_script() {
  echo "<span class="math-inline">\{YELLOW\}更新本脚本功能需要配置 GitHub 仓库信息才能自动完成。</span>{NC}"
  echo "<span class="math-inline">\{YELLOW\}请手动从 GitHub 下载最新版本并替换。</span>{NC}"
  read -n 1 -s -p "<span class="math-inline">\{YELLOW\}按任意键返回主菜单\.\.\.</span>{NC}"
  echo ""
}

# 函数：配置系统环境子菜单
config_system_env() {
  while true
  do
    echo ""
    echo "<span class="math-inline">\{YELLOW\}配置系统环境：</span>{NC}"
    echo "<span class="math-inline">\{BLUE\}1\.</span>{NC} 更新系统 (apt update && apt upgrade -y)"
    echo "<span class="math-inline">\{BLUE\}2\.</span>{NC} 安装系统必要环境 (apt install unzip curl wget git sudo -y)"
    echo "<span class="math-inline">\{BLUE\}3\.</span>{NC} 开启 BBR v3 加速"
    echo "<span class="math-inline">\{BLUE\}4\.</span>{NC} 开启 BBR v3 + FQ 策略 (如果 BBR v3 已启用)"
    echo "<span class="math-inline">\{BLUE\}5\.</span>{NC} 开放所有端口 (清空防火墙规则)"
    echo "<span class="math-inline">\{BLUE\}6\.</span>{NC} 切换 IPv4/IPv6 优先"
    echo "<span class="math-inline">\{BLUE\}9\.</span>{NC} 返回主菜单"
    echo "<span class="math-inline">\{BLUE\}0\.</span>{NC} 退出脚本${NC}"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "<span class="math-inline">sub\_choice" in
1\)
echo "</span>{YELLOW}正在更新系统，请稍候...<span class="math-inline">\{NC\}"
sudo apt update \-y
sudo apt upgrade \-y
echo "</span>{GREEN}系统更新完成。<span class="math-inline">\{NC\}"
;;
2\)
echo "</span>{YELLOW}正在安装必要环境，请稍候...<span class="math-inline">\{NC\}"
sudo apt install unzip curl wget git sudo \-y
echo "</span>{GREEN}必要环境安装完成。<span class="math-inline">\{NC\}"
;;
3\)
enable\_bbrv3
;;
4\)
enable\_bbr\_fq
;;
5\)
open\_all\_ports
;;
6\)
toggle\_ipv4\_ipv6\_preference
;;
9\)
break \# 返回主菜单
;;
0\)
echo "</span>{YELLOW}退出脚本。<span class="math-inline">\{NC\}"
exit 0
;;
\*\)
echo "</span>{RED}无效的指令，请重新输入。${NC}"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "<span class="math-inline">sub\_choice" \!\= "9" \]; then
read \-n 1 \-s \-p "</span>{YELLOW}按任意键继续...<span class="math-inline">\{NC\}"
echo "" \# 为了换行
fi
done
\}
\# 函数：开启 BBR v3 加速
enable\_bbrv3\(\) \{
echo "</span>{YELLOW}正在尝试开启 BBR v3 加速...<span class="math-inline">\{NC\}"
\# 检查内核版本是否支持 BBR v3 \(通常 Linux 5\.15 及以上\)
kernel\_version\=</span>(uname -r | awk -F'.' '{print $1"."$2}')
  if (( $(echo "$kernel_version" | bc -l) >= <span class="math-inline">\(echo "5\.15" \| bc \-l\) \)\); then
sudo sysctl \-w net\.core\.default\_qdisc\=cake
sudo sysctl \-w net\.ipv4\.tcp\_congestion\_control\=bbr3
echo "</span>{GREEN}BBR v3 加速已开启。<span class="math-inline">\{NC\}"
\# 持久化配置
sudo sh \-c "echo 'net\.core\.default\_qdisc\=cake' \>\> /etc/sysctl\.conf"
sudo sh \-c "echo 'net\.ipv4\.tcp\_congestion\_control\=bbr3' \>\> /etc/sysctl\.conf"
sudo sysctl \-p
else
echo "</span>{YELLOW}当前内核版本 (<span class="math-inline">kernel\_version\) 可能不支持 BBR v3，跳过。</span>{NC}"
  fi
}

# 函数：开启 BBR v3 + FQ 策略
enable_bbr_fq() {
  echo "<span class="math-inline">\{YELLOW\}正在尝试开启 BBR v3 \+ FQ 策略\.\.\.</span>{NC}"
  # 假设已经开启了 BBR v3，这里只修改拥塞控制算法
  current_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
  if [ "<span class="math-inline">current\_congestion\_control" \=\= "bbr3" \]; then
sudo sysctl \-w net\.core\.default\_qdisc\=fq
sudo sysctl \-w net\.ipv4\.tcp\_congestion\_control\=bbr3
echo "</span>{GREEN}BBR v3 + FQ 策略已开启。<span class="math-inline">\{NC\}"
\# 持久化配置
sudo sh \-c "echo 'net\.core\.default\_qdisc\=fq' \>\> /etc/sysctl\.conf"
sudo sh \-c "echo 'net\.ipv4\.tcp\_congestion\_control\=bbr3' \>\> /etc/sysctl\.conf"
sudo sysctl \-p
else
echo "</span>{YELLOW}请先开启 BBR v3，才能启用 BBR v3 + FQ 策略。<span class="math-inline">\{NC\}"
fi
\}
\# 函数：开放所有端口 \(清空防火墙规则\)
open\_all\_ports\(\) \{
echo "</span>{RED}警告：您将要开放所有端口，这可能会带来安全风险！${NC}"
  read -p "您确定要继续吗？ (y/N): " confirm_open_ports
  if [[ "$confirm_open_ports" == "y" || "<span class="math-inline">confirm\_open\_ports" \=\= "Y" \]\]; then
echo "</span>{YELLOW}正在清空防火墙规则...<span class="math-inline">\{NC\}"
sudo iptables \-F
sudo iptables \-X
sudo iptables \-Z
sudo ip6tables \-F
sudo ip6tables \-X
sudo ip6tables \-Z
echo "</span>{GREEN}防火墙规则已清空，所有端口已开放。<span class="math-inline">\{NC\}"
else
echo "</span>{YELLOW}已取消开放所有端口的操作。<span class="math-inline">\{NC\}"
fi
\}
\# 函数：切换 IPv4/IPv6 优先
toggle\_ipv4\_ipv6\_preference\(\) \{
current\_preference\=</span>(sysctl net.ipv6.prefer_inet6 | awk '{print $3}')
  if [ "<span class="math-inline">current\_preference" \-eq 0 \]; then
echo "</span>{YELLOW}当前 IPv4 优先。切换到 IPv6 优先...<span class="math-inline">\{NC\}"
sudo sysctl \-w net\.ipv6\.prefer\_inet6\=1
sudo sh \-c "echo 'net\.ipv6\.prefer\_inet6\=1' \>\> /etc/sysctl\.conf"
sudo sysctl \-p
echo "</span>{GREEN}已切换到 IPv6 优先。<span class="math-inline">\{NC\}"
else
echo "</span>{YELLOW}当前 IPv6 优先。切换到 IPv4 优先...<span class="math-inline">\{NC\}"
sudo sysctl \-w net\.ipv6\.prefer\_inet6\=0
sudo sh \-c "echo 'net\.ipv6\.prefer\_inet6\=0' \>\> /etc/sysctl\.conf"
sudo sysctl \-p
echo "</span>{GREEN}已切换到 IPv4 优先。<span class="math-inline">\{NC\}"
fi
\}
\# 函数：测试脚本合集子菜单
test\_scripts\_menu\(\) \{
while true; do
echo ""
echo "</span>{YELLOW}测试脚本合集：<span class="math-inline">\{NC\}"
echo "</span>{BLUE}1.<span class="math-inline">\{NC\} NodeQuality 测试 \(bash <\(curl \-sL https\://run\.NodeQuality\.com\)\)"
echo "</span>{BLUE}9.<span class="math-inline">\{NC\} 返回主菜单"
echo "</span>{BLUE}0.<span class="math-inline">\{NC\} 退出脚本</span>{NC}"
    echo ""
    read -p "请输入指令数字并按 Enter 键: " sub_choice
    case "<span class="math-inline">sub\_choice" in
1\)
echo "</span>{YELLOW}正在运行 NodeQuality 测试脚本，请稍候...<span class="math-inline">\{NC\}"
bash <\(curl \-sL https\://run\.NodeQuality\.com\)
echo "</span>{GREEN}NodeQuality 测试完成。<span class="math-inline">\{NC\}"
;;
9\)
break \# 返回主菜单
;;
0\)
echo "</span>{YELLOW}退出脚本。<span class="math-inline">\{NC\}"
exit 0
;;
\*\)
echo "</span>{RED}无效的指令，请重新输入。${NC}"
        ;;
    esac
    if [ "$sub_choice" != "0" ] && [ "<span class="math-inline">sub\_choice" \!\= "9" \]; then
read \-n 1 \-s \-p "</span>{YELLOW}按任意键继续...${NC}"
      echo "" # 为了换行
    fi
  done
}

# 主循环
while true; do
  show_main_menu
  case "<span class="math-inline">main\_choice" in
1\)
config\_system\_env
;;
2\)
test\_scripts\_menu
;;
3\)
update\_script
;;
0\)
echo "</span>{YELLOW}退出脚本。<span class="math-inline">\{NC\}"
exit 0
;;
\*\)
echo "</span>{RED}无效的指令，请重新输入。${NC}"
      ;;
  esac
done
