#!/bin/bash

# SOCKS5 一键安装脚本 (Dante Server)
# 支持系统: CentOS/Debian/Ubuntu/Alpine
# 日期: 2025-05-26

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要 root 权限运行此脚本${NC}"
    exit 1
fi

# 检测系统
detect_system() {
    if [[ -f /etc/alpine-release ]]; then
        OS="alpine"
        PKG_MANAGER="apk"
        SERVICE_CMD="rc-service"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
        PKG_MANAGER="apt"
        SERVICE_CMD="systemctl"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PKG_MANAGER="yum"
        SERVICE_CMD="systemctl"
    else
        echo -e "${RED}不支持的系统${NC}"
        exit 1
    fi
}

# 安装 dante-server
install_dante() {
    echo -e "${GREEN}正在安装 dante-server...${NC}"
    
    case $PKG_MANAGER in
        apk)
            apk update && apk add --no-cache dante-server
            ;;
        apt)
            apt update && apt install -y dante-server
            ;;
        yum)
            yum install -y epel-release && yum install -y dante-server
            ;;
    esac
}

# 创建配置文件
create_config() {
    local user=$1
    local pass=$2
    local port=$3
    
    # 获取网络接口
    local interface=$(ip route | grep default | awk '{print $5}' | head -1 || echo "eth0")
    
    # 创建用户
    if ! id "$user" &>/dev/null; then
        case $OS in
            alpine) adduser -D -s /bin/false "$user" ;;
            *) useradd -r -s /bin/false "$user" ;;
        esac
    fi
    echo "$user:$pass" | chpasswd
    
    # 创建配置目录
    mkdir -p /var/log/sockd
    
    # 生成配置文件
    cat > /etc/sockd.conf << EOF
logoutput: /var/log/sockd/sockd.log
internal: 0.0.0.0 port = $port
external: $interface
socksmethod: username
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    socksmethod: username
    log: error
}
EOF

    echo -e "${GREEN}配置文件已创建${NC}"
}

# 启动服务
start_service() {
    if [[ $OS == "alpine" ]]; then
        # Alpine 使用系统自带的 sockd 服务
        rc-update add sockd default
        rc-service sockd start
    else
        # SystemD
        cat > /etc/systemd/system/sockd.service << EOF
[Unit]
Description=Dante SOCKS5 Server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/sockd.pid
ExecStart=/usr/sbin/sockd -f /etc/sockd.conf -P /var/run/sockd.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable sockd
        systemctl start sockd
    fi
}

# 配置防火墙
setup_firewall() {
    local port=$1
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${port}/tcp
        firewall-cmd --reload
    elif command -v ufw >/dev/null 2>&1; then
        ufw allow ${port}/tcp
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
}

# 安装函数
install_socks5() {
    echo -e "${BLUE}======= SOCKS5 安装 =======${NC}"
    
    read -p "请输入用户名 [默认: admin]: " username
    username=${username:-admin}
    
    while true; do
        read -s -p "请输入密码: " password
        echo
        [[ -n "$password" ]] && break
        echo -e "${RED}密码不能为空${NC}"
    done
    
    read -p "请输入端口 [默认: 1080]: " port
    port=${port:-1080}
    
    echo -e "\n${YELLOW}配置信息:${NC}"
    echo "用户名: $username"
    echo "密码: ********"
    echo "端口: $port"
    
    read -p "确认安装? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0
    
    detect_system
    install_dante
    create_config "$username" "$password" "$port"
    start_service
    setup_firewall "$port"
    
    echo -e "${GREEN}✅ 安装完成！${NC}"
    echo -e "${BLUE}连接信息:${NC}"
    echo "服务器: $(curl -s ifconfig.me 2>/dev/null || echo '您的服务器IP')"
    echo "端口: $port"
    echo "用户名: $username"
    echo "密码: $password"
}

# 卸载函数
uninstall_socks5() {
    echo -e "${YELLOW}正在卸载 SOCKS5 服务...${NC}"
    
    detect_system
    
    # 停止服务
    if [[ $OS == "alpine" ]]; then
        rc-service sockd stop 2>/dev/null || true
        rc-update del sockd default 2>/dev/null || true
    else
        systemctl stop sockd 2>/dev/null || true
        systemctl disable sockd 2>/dev/null || true
        rm -f /etc/systemd/system/sockd.service
        systemctl daemon-reload
    fi
    
    # 删除配置文件
    rm -f /etc/sockd.conf
    rm -rf /var/log/sockd
    
    # 卸载软件包
    case $PKG_MANAGER in
        apk) apk del dante-server ;;
        apt) apt remove -y dante-server ;;
        yum) yum remove -y dante-server ;;
    esac
    
    echo -e "${GREEN}✅ 卸载完成${NC}"
}

# 显示状态
show_status() {
    detect_system
    
    echo -e "${BLUE}======= 服务状态 =======${NC}"
    
    if [[ $OS == "alpine" ]]; then
        rc-service sockd status
    else
        systemctl status sockd
    fi
}

# 主菜单
main_menu() {
    echo -e "${BLUE}"
    cat << "EOF"
 ____   ___   ____ _  ______  ____  
/ ___| / _ \ / ___| |/ / ___||  _ \ 
\___ \| | | | |   | ' /\___ \| |_) |
 ___) | |_| | |___| . \ ___) |  __/ 
|____/ \___/ \____|_|\_\____/|_|    

    SOCKS5 一键安装脚本 (Dante)
    支持 CentOS/Debian/Ubuntu/Alpine
EOF
    echo -e "${NC}"
    
    echo "1. 安装 SOCKS5"
    echo "2. 卸载 SOCKS5"
    echo "3. 查看状态"
    echo "0. 退出"
    echo
    
    read -p "请选择 [0-3]: " choice
    
    case $choice in
        1) install_socks5 ;;
        2) uninstall_socks5 ;;
        3) show_status ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" && main_menu ;;
    esac
}

# 启动主菜单
main_menu
