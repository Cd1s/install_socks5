#!/bin/bash

# SOCKS5 一键安装脚本 2025版
# 支持系统: CentOS, Debian, Ubuntu, Alpine
# 作者: GitHub Copilot
# 日期: 2025-05-25

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=1080
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD=""
SOCKS5_USER=""
SOCKS5_PASS=""
SOCKS5_PORT=""

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统类型
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        if command -v dnf >/dev/null 2>&1; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="yum"
        fi
    elif [[ -f /etc/debian_version ]]; then
        if grep -qi ubuntu /etc/os-release; then
            OS="ubuntu"
        else
            OS="debian"
        fi
        PKG_MANAGER="apt"
    elif [[ -f /etc/alpine-release ]]; then
        OS="alpine"
        PKG_MANAGER="apk"
    else
        log_error "不支持的操作系统"
        exit 1
    fi
    
    log_info "检测到系统: $OS"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "正在安装依赖包..."
    
    case $OS in
        "centos")
            $PKG_MANAGER update -y
            $PKG_MANAGER install -y wget curl gcc gcc-c++ make git
            ;;
        "ubuntu"|"debian")
            $PKG_MANAGER update -y
            $PKG_MANAGER install -y wget curl build-essential git
            ;;
        "alpine")
            $PKG_MANAGER update
            $PKG_MANAGER add wget curl gcc g++ make git musl-dev
            ;;
    esac
}

# 获取用户输入
get_user_input() {
    echo -e "${BLUE}======= SOCKS5 配置向导 =======${NC}"
    
    # 用户名
    read -p "请输入SOCKS5用户名 [默认: $DEFAULT_USERNAME]: " input_username
    SOCKS5_USER=${input_username:-$DEFAULT_USERNAME}
    
    # 密码
    while [[ -z "$SOCKS5_PASS" ]]; do
        read -s -p "请输入SOCKS5密码: " input_password
        echo
        if [[ -n "$input_password" ]]; then
            SOCKS5_PASS="$input_password"
        else
            log_warn "密码不能为空，请重新输入"
        fi
    done
    
    # 端口
    while true; do
        read -p "请输入SOCKS5端口 [默认: $DEFAULT_PORT]: " input_port
        SOCKS5_PORT=${input_port:-$DEFAULT_PORT}
        
        if [[ $SOCKS5_PORT =~ ^[0-9]+$ ]] && [ $SOCKS5_PORT -ge 1 ] && [ $SOCKS5_PORT -le 65535 ]; then
            if ! netstat -tuln 2>/dev/null | grep -q ":$SOCKS5_PORT "; then
                break
            else
                log_warn "端口 $SOCKS5_PORT 已被占用，请选择其他端口"
            fi
        else
            log_warn "请输入有效的端口号 (1-65535)"
        fi
    done
    
    # 确认配置
    echo -e "\n${BLUE}======= 配置确认 =======${NC}"
    echo "用户名: $SOCKS5_USER"
    echo "密码: ${SOCKS5_PASS//?/*}"
    echo "端口: $SOCKS5_PORT"
    echo
    
    read -p "确认以上配置？[y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "配置取消，重新开始..."
        get_user_input
    fi
}

# 安装 3proxy
install_3proxy() {
    log_info "正在下载并编译 3proxy..."
    
    cd /tmp
    wget -O 3proxy.tar.gz https://github.com/z3APA3A/3proxy/archive/0.9.3.tar.gz
    tar -xzf 3proxy.tar.gz
    cd 3proxy-0.9.3
    
    make -f Makefile.Linux
    
    # 创建目录和复制文件
    mkdir -p /etc/3proxy
    mkdir -p /var/log/3proxy
    cp bin/3proxy /usr/local/bin/
    chmod +x /usr/local/bin/3proxy
    
    log_info "3proxy 安装完成"
}

# 创建配置文件
create_config() {
    log_info "正在创建配置文件..."
    
    cat > /etc/3proxy/3proxy.cfg << EOF
# 3proxy 配置文件
daemon
pidfile /var/run/3proxy.pid
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 认证
auth strong
users $SOCKS5_USER:CL:$SOCKS5_PASS

# 日志
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# 访问控制
allow $SOCKS5_USER

# SOCKS5 代理
socks -p$SOCKS5_PORT
EOF

    log_info "配置文件创建完成"
}

# 创建systemd服务
create_systemd_service() {
    log_info "正在创建systemd服务..."
    
    cat > /etc/systemd/system/3proxy.service << EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=forking
User=root
Group=root
PIDFile=/var/run/3proxy.pid
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -USR1 \$MAINPID
Restart=on-failure
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable 3proxy
    
    log_info "systemd服务创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "正在配置防火墙..."
    
    case $OS in
        "centos")
            if systemctl is-active --quiet firewalld; then
                firewall-cmd --permanent --add-port=$SOCKS5_PORT/tcp
                firewall-cmd --reload
                log_info "firewalld 规则已添加"
            elif systemctl is-active --quiet iptables; then
                iptables -I INPUT -p tcp --dport $SOCKS5_PORT -j ACCEPT
                service iptables save 2>/dev/null || true
                log_info "iptables 规则已添加"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw >/dev/null 2>&1; then
                ufw allow $SOCKS5_PORT/tcp
                log_info "ufw 规则已添加"
            elif command -v iptables >/dev/null 2>&1; then
                iptables -I INPUT -p tcp --dport $SOCKS5_PORT -j ACCEPT
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
                log_info "iptables 规则已添加"
            fi
            ;;
        "alpine")
            if command -v iptables >/dev/null 2>&1; then
                iptables -I INPUT -p tcp --dport $SOCKS5_PORT -j ACCEPT
                /etc/init.d/iptables save 2>/dev/null || true
                log_info "iptables 规则已添加"
            fi
            ;;
    esac
}

# 启动服务
start_service() {
    log_info "正在启动SOCKS5服务..."
    
    systemctl start 3proxy
    sleep 2
    
    if systemctl is-active --quiet 3proxy; then
        log_info "SOCKS5服务启动成功"
    else
        log_error "SOCKS5服务启动失败"
        systemctl status 3proxy
        exit 1
    fi
}

# 显示连接信息
show_connection_info() {
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo -e "\n${GREEN}======= 安装完成 =======${NC}"
    echo -e "${GREEN}SOCKS5代理信息:${NC}"
    echo "服务器IP: $server_ip"
    echo "端口: $SOCKS5_PORT"
    echo "用户名: $SOCKS5_USER"
    echo "密码: $SOCKS5_PASS"
    echo "协议: SOCKS5"
    echo
    echo -e "${GREEN}服务管理命令:${NC}"
    echo "启动服务: systemctl start 3proxy"
    echo "停止服务: systemctl stop 3proxy"
    echo "重启服务: systemctl restart 3proxy"
    echo "查看状态: systemctl status 3proxy"
    echo "查看日志: tail -f /var/log/3proxy/3proxy.log"
    echo
    echo -e "${GREEN}配置文件位置:${NC}"
    echo "主配置: /etc/3proxy/3proxy.cfg"
    echo "服务文件: /etc/systemd/system/3proxy.service"
    echo
    echo -e "${YELLOW}请确保在客户端中正确配置上述SOCKS5信息${NC}"
}

# 卸载功能
uninstall_socks5() {
    echo -e "${YELLOW}正在卸载SOCKS5服务...${NC}"
    
    systemctl stop 3proxy 2>/dev/null || true
    systemctl disable 3proxy 2>/dev/null || true
    rm -f /etc/systemd/system/3proxy.service
    rm -f /usr/local/bin/3proxy
    rm -rf /etc/3proxy
    rm -rf /var/log/3proxy
    systemctl daemon-reload
    
    log_info "SOCKS5服务已完全卸载"
}

# 主菜单
show_menu() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "        SOCKS5 一键安装脚本 2025"
    echo "========================================"
    echo -e "${NC}"
    echo "1. 安装 SOCKS5 代理"
    echo "2. 卸载 SOCKS5 代理"
    echo "3. 查看连接信息"
    echo "4. 重启服务"
    echo "5. 查看服务状态"
    echo "0. 退出"
    echo
}

# 主函数
main() {
    check_root
    detect_os
    
    while true; do
        show_menu
        read -p "请选择操作 [0-5]: " choice
        
        case $choice in
            1)
                get_user_input
                install_dependencies
                install_3proxy
                create_config
                create_systemd_service
                configure_firewall
                start_service
                show_connection_info
                break
                ;;
            2)
                uninstall_socks5
                break
                ;;
            3)
                if systemctl is-active --quiet 3proxy 2>/dev/null; then
                    show_connection_info
                else
                    log_warn "SOCKS5服务未运行"
                fi
                ;;
            4)
                systemctl restart 3proxy
                log_info "服务已重启"
                ;;
            5)
                systemctl status 3proxy
                ;;
            0)
                log_info "感谢使用！"
                exit 0
                ;;
            *)
                log_warn "无效选择，请重新输入"
                ;;
        esac
    done
}

# 脚本入口
main "$@"
