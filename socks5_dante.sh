#!/bin/bash

# 脚本功能: 一键安装和管理 Dante SOCKS5 服务器
# 支持系统: CentOS, Debian, Ubuntu, Alpine
# 特点: 设置用户密码, 删除用户, 开机自启

# 发生错误时退出
set -e

# --- 变量定义 ---
SOCKS_PORT_DEFAULT="1080"        # SOCKS5 默认监听端口
CONFIG_FILE="/etc/danted.conf"   # Dante 配置文件路径
SERVICE_NAME="danted"            # Dante 服务名称
OS=""                            # 操作系统类型 (自动检测)
OS_VERSION=""                    # 操作系统版本 (自动检测)

# --- 辅助函数 ---

# 打印普通信息
_log() {
    echo -e "\033[0;32m信息: $1\033[0m" # 绿色输出
}

# 打印警告信息
_warn() {
    echo -e "\033[0;33m警告: $1\033[0m" # 黄色输出
}

# 打印错误信息并退出
_error() {
    echo -e "\033[0;31m错误: $1\033[0m" >&2 # 红色输出
    exit 1
}

# 检查是否以 root 用户运行
_check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        _error "此脚本必须以 root 用户身份运行。"
    fi
}

# 检测操作系统
_detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/centos-release ]; then
        OS="centos"
        OS_VERSION=$(cat /etc/centos-release | sed 's/.*release //;s/ .*//' | cut -d. -f1) # 获取主版本号
    elif [ -f /etc/redhat-release ]; then #兼容老版本 RHEL
        OS="rhel" # 作为 centos 处理
        OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release //;s/ .*//' | cut -d. -f1)
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
        OS_VERSION=$(cat /etc/alpine-release)
    else
        _error "无法检测到或不支持当前操作系统。"
    fi
    OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]') # 转换为小写
    _log "检测到操作系统: $OS $OS_VERSION"
}

# 安装 dante-server 软件包
_install_packages() {
    _log "正在更新软件包列表并安装 dante-server 及其依赖..."
    case "$OS" in
        centos|rhel)
            _log "正在为 $OS 安装 EPEL 源 (如果需要) 和 dante-server..."
            if ! rpm -q epel-release &>/dev/null; then
                sudo yum install -y epel-release || sudo dnf install -y epel-release
            fi
            if command -v dnf &> /dev/null; then
                sudo dnf install -y dante-server util-linux # util-linux 提供 chpasswd
            else
                sudo yum install -y dante-server util-linux
            fi
            ;;
        debian|ubuntu) # 将 ubuntu 视为 debian 处理
            _log "正在为 $OS 更新并安装 dante-server..."
            sudo apt-get update -y
            sudo apt-get install -y dante-server passwd # passwd 提供 chpasswd
            ;;
        alpine)
            _log "正在为 $OS 更新并安装 dante-server..."
            sudo apk update
            sudo apk add dante-server shadow # shadow 提供 chpasswd 及用户管理工具
            ;;
        *)
            _error "未针对 $OS ($OS_VERSION) 配置软件包安装流程。"
            ;;
    esac
    if ! command -v $SERVICE_NAME &> /dev/null && ! command -v sockd &> /dev/null ; then
        _error "dante-server 安装失败，请检查系统和网络。"
    fi
    # 确保服务名正确，有些系统可能是 sockd
    if command -v sockd &> /dev/null && ! command -v $SERVICE_NAME &> /dev/null; then
        SERVICE_NAME="sockd"
        CONFIG_FILE="/etc/sockd.conf" # Alpine 上可能是 sockd.conf
        _warn "Dante 服务名似乎是 'sockd'，配置文件可能是 '$CONFIG_FILE'。"
    fi

    _log "dante-server 安装成功。"
}

# 配置 Dante 服务器
_configure_dante() {
    local port="$1"
    _log "正在配置 dante-server, 监听端口 $port..."
    _log "配置文件路径: $CONFIG_FILE"

    # 创建 PID 文件目录 (某些 Dante 版本可能需要)
    # Dante 服务启动脚本通常会处理这个，但以防万一
    if [ "$SERVICE_NAME" == "danted" ]; then
         sudo mkdir -p /var/run/danted
         # user.unprivileged 默认为 nobody, nogroup 或 nobody 组
         # chown nobody:nobody /var/run/danted # 根据实际情况调整
    fi


    cat <<EOF | sudo tee "$CONFIG_FILE" > /dev/null
# Dante SOCKS Server Configuration File
# 生成于: $(date) by install script

# 日志输出: 使用系统日志 syslog
logoutput: syslog
# 如果想用文件日志，可以取消注释下一行，并确保 dante 进程有权限写入
# logoutput: /var/log/${SERVICE_NAME}.log

# 内部网络接口和监听端口
# 监听所有 IPv4 地址
internal: 0.0.0.0 port = $port
# 如果需要监听 IPv6:
# internal: ::0 port = $port

# 外部网络接口选择 (用于出站连接)
# 使用系统路由表自动决定出站接口，适用于大多数情况
external.rotation: route

# SOCKS 协议认证方法
# 'username' 表示使用系统用户进行用户名/密码认证
socksmethod: username

# Dante 服务自身运行的用户权限
user.privileged: root      # 处理特权操作的用户 (如绑定低端口)
user.unprivileged: nobody  # 日常运行的非特权用户 (或 danted, sockd 等专用用户)

# 客户端连接规则
# 允许所有来源的客户端连接到代理服务器
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect iooperation # 记录错误、连接、断开和IO操作
}

# SOCKS 请求规则
# 允许通过认证的客户端执行 SOCKS 命令 (connect, bind, udpassociate)
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect iooperation # 记录详细信息
    socksmethod: username # 对 SOCKS 请求强制使用用户名/密码认证
}
EOF
    _log "Dante 配置文件已写入 $CONFIG_FILE。"
}

# 添加 SOCKS5 用户 (作为系统用户)
_add_user() {
    local username
    local password
    local password_confirm

    read -p "请输入 SOCKS5 代理的新用户名: " username
    if [[ -z "$username" ]]; then
        _error "用户名不能为空。"
    fi
    if id "$username" &>/dev/null; then
        _warn "系统用户 '$username' 已存在。"
        read -p "该用户已存在。您想为该用户重设SOCKS代理密码吗? (yes/no): " reset_password
        if [[ "${reset_password,,}" != "yes" ]]; then
            _log "操作取消。"
            return
        fi
    fi

    read -s -p "请输入用户 '$username' 的密码: " password
    echo
    if [[ -z "$password" ]]; then
        _error "密码不能为空。"
    fi
    read -s -p "请再次输入密码以确认: " password_confirm
    echo
    if [[ "$password" != "$password_confirm" ]]; then
        _error "两次输入的密码不匹配。"
    fi

    if ! id "$username" &>/dev/null; then
        _log "正在为 SOCKS5 代理添加新的系统用户 '$username'..."
        case "$OS" in
            alpine)
                # -D: 不分配密码 (后续用 chpasswd 设置)
                # -H: 不创建家目录
                # -s /sbin/nologin: 禁止shell登录
                # -G nogroup: Alpine中常见的做法，或者创建一个专用的组
                sudo adduser -D -H -s /sbin/nologin "$username"
                ;;
            *) # Debian, Ubuntu, CentOS, RHEL
                # -r: 创建系统账户 (更安全，ID通常较低)
                # -M: 不创建家目录
                # -N: 不创建同名用户组 (避免不必要的组)
                # -s /usr/sbin/nologin: 设置 nologin shell，禁止登录
                if ! sudo useradd -r -M -N -s /usr/sbin/nologin "$username" 2>/dev/null; then
                    _warn "使用 'useradd -r' 创建系统用户失败, 尝试不带 '-r' 选项..."
                    sudo useradd -M -N -s /usr/sbin/nologin "$username"
                fi
                ;;
        esac
        _log "系统用户 '$username' 创建成功。"
    else
        _log "系统用户 '$username' 已存在，将直接更新其密码用于SOCKS代理。"
    fi


    echo "$username:$password" | sudo chpasswd
    _log "用户 '$username' 的 SOCKS5 代理密码设置/更新成功。"
}

# 删除 SOCKS5 用户 (即删除对应的系统用户)
_delete_user() {
    local username
    read -p "请输入要删除的 SOCKS5 用户名 (此操作将删除对应系统用户): " username
    if [[ -z "$username" ]]; then
        _error "用户名不能为空。"
    fi

    if ! id "$username" &>/dev/null; then
        _error "用户 '$username' 不存在。"
    fi

    # 安全检查，防止误删重要系统用户
    case "$username" in
        root|admin|adm|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|systemd-network|systemd-resolve|systemd-timesync|debian|ubuntu|centos|alpine|ec2-user)
            _error "出于安全原因，禁止通过此脚本删除预设的系统用户或常用管理员账户 '$username'。"
            ;;
    esac
    # 可根据需要添加更多检查，比如检查用户 UID 范围（例如，UID < 1000 的通常是系统用户）
    local user_uid
    user_uid=$(id -u "$username")
    if [[ "$user_uid" -lt 1000 && "$user_uid" -ne 0 ]]; then # 排除root (uid 0)
        _warn "用户 '$username' (UID: $user_uid) 看起来像一个系统服务账户。"
        read -p "您确定要删除这个用户吗? (yes/no): " confirm_del_sys_user
        if [[ "${confirm_del_sys_user,,}" != "yes" ]]; then
            _log "删除操作已取消。"
            return
        fi
    fi


    _log "正在删除用户 '$username'..."
    if sudo userdel "$username"; then
        _log "用户 '$username' 删除成功。"
    else
        _warn "删除用户 '$username' 失败 (可能因为用户仍有运行中的进程)。"
        read -p "是否尝试强制删除用户 '$username' (包括其家目录和邮件池，如果存在)? (yes/no): " force_delete
        if [[ "${force_delete,,}" == "yes" ]]; then
            if sudo userdel -r -f "$username"; then # -r 删除家目录和邮箱, -f 强制
                _log "用户 '$username' 已被强制删除。"
            else
                _error "强制删除用户 '$username' 也失败了。请手动检查并处理。"
            fi
        else
            _log "未执行强制删除。请检查用户 '$username' 的状态。"
        fi
    fi
}

# 启用并启动/重启 dante-server 服务，并设置为开机自启
_ensure_service_running() {
    local action="restart" # 默认为重启，确保配置加载
    if ! _is_service_active; then
        action="start" # 如果服务未激活，则启动
    fi

    _log "正在 $action $SERVICE_NAME 服务并设置为开机自启..."
    case "$OS" in
        centos|rhel|debian|ubuntu)
            sudo systemctl enable "$SERVICE_NAME"
            sudo systemctl "$action" "$SERVICE_NAME" # 使用 start 或 restart
            _log "检查 $SERVICE_NAME 服务状态:"
            sudo systemctl status "$SERVICE_NAME" --no-pager || true # 不因status非0退出脚本
            ;;
        alpine)
            sudo rc-update add "$SERVICE_NAME" default
            sudo rc-service "$SERVICE_NAME" "$action" # 使用 start 或 restart
            _log "检查 $SERVICE_NAME 服务状态:"
            sudo rc-service "$SERVICE_NAME" status || true # 不因status非0退出脚本
            ;;
        *)
            _error "未针对 $OS ($OS_VERSION) 配置服务管理。"
            ;;
    esac
    if _is_service_active; then
        _log "$SERVICE_NAME 服务已运行并设置为开机自启。"
    else
        _error "$SERVICE_NAME 服务未能成功启动。请检查日志。"
    fi
}

# 重启服务
_restart_service() {
    _log "正在重启 $SERVICE_NAME 服务..."
     case "$OS" in
        centos|rhel|debian|ubuntu)
            sudo systemctl restart "$SERVICE_NAME"
            _log "检查 $SERVICE_NAME 服务状态:"
            sudo systemctl status "$SERVICE_NAME" --no-pager || true
            ;;
        alpine)
            sudo rc-service "$SERVICE_NAME" restart
            _log "检查 $SERVICE_NAME 服务状态:"
            sudo rc-service "$SERVICE_NAME" status || true
            ;;
        *)
            _error "未针对 $OS ($OS_VERSION) 配置服务重启。"
            ;;
    esac
    if ! _is_service_active; then
         _warn "$SERVICE_NAME 服务重启后似乎未激活。请检查日志。"
    fi
}

# 检查服务是否激活
_is_service_active() {
    case "$OS" in
        centos|rhel|debian|ubuntu)
            sudo systemctl is-active "$SERVICE_NAME" &>/dev/null
            ;;
        alpine)
            # rc-service status exits 0 if running, 3 if stopped, 1 if crashed
            # We only care if it's truly running (exit code 0 for status)
            sudo rc-service "$SERVICE_NAME" status &>/dev/null && [[ $? -eq 0 ]]
            ;;
        *)
            return 1 # Unknown, assume not active
            ;;
    esac
}

# 显示服务状态
_show_status() {
    _log "正在检查 $SERVICE_NAME 服务状态..."
    # 先检查服务是否已安装或可识别
    if ! command -v $SERVICE_NAME &> /dev/null && ! [ -f "/etc/init.d/$SERVICE_NAME" ] && ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
         _warn "Dante 服务 ($SERVICE_NAME) 似乎未安装或未正确配置为系统服务。"
         if [ -f "$CONFIG_FILE" ]; then
            _log "但找到了配置文件 $CONFIG_FILE。"
         fi
         return 1
    fi

    case "$OS" in
        centos|rhel|debian|ubuntu)
            sudo systemctl status "$SERVICE_NAME" --no-pager || true
            ;;
        alpine)
            sudo rc-service "$SERVICE_NAME" status || true
            ;;
        *)
            _error "未针对 $OS ($OS_VERSION) 配置服务状态检查。"
            ;;
    esac
}

# 主要安装函数
_install_dante() {
    local port
    read -p "请输入 SOCKS5 代理的监听端口 (默认: $SOCKS_PORT_DEFAULT): " port
    port=${port:-$SOCKS_PORT_DEFAULT} # 如果输入为空则使用默认值

    # 校验端口号
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        _error "无效的端口号。必须是 1 到 65535 之间的数字。"
    fi
    if [[ "$port" -lt 1024 ]]; then
        _warn "您选择了一个特权端口 ($port < 1024)。请确保以root权限运行Dante或正确配置 user.privileged。"
    fi

    _install_packages
    _configure_dante "$port"
    _log "初始配置完成。现在，我们来添加第一个代理用户。"
    _add_user # 添加第一个用户
    _ensure_service_running # 启动或重启服务并设置自启
    _log "🎉 Dante SOCKS5 服务器安装和配置完成! 🎉"
    _log "代理正在运行在所有IP地址的端口 $port 上。"
    _log "您可以使用 '$0 adduser' 命令添加更多用户。"
    _log "使用 '$0 deluser <username>' 删除用户。"
    _log "使用 '$0 status' 查看服务状态, '$0 restart' 重启服务。"
}

# 卸载 Dante 函数
_uninstall_dante() {
    _warn "警告：此操作将尝试卸载 dante-server 并可能移除其配置文件。"
    read -p "您确定要卸载 Dante SOCKS5 服务器吗? (yes/no): " confirmation
    if [[ "${confirmation,,}" != "yes" ]]; then # 转小写比较
        _log "卸载操作已取消。"
        return
    fi

    _log "正在尝试停止并禁用 $SERVICE_NAME 服务..."
    case "$OS" in
        centos|rhel|debian|ubuntu)
            sudo systemctl stop "$SERVICE_NAME" &>/dev/null || _warn "停止服务 $SERVICE_NAME 失败或服务未运行。"
            sudo systemctl disable "$SERVICE_NAME" &>/dev/null || _warn "禁用服务 $SERVICE_NAME 自启失败或服务未启用。"
            ;;
        alpine)
            sudo rc-service "$SERVICE_NAME" stop &>/dev/null || _warn "停止服务 $SERVICE_NAME 失败或服务未运行。"
            sudo rc-update del "$SERVICE_NAME" default &>/dev/null || _warn "禁用服务 $SERVICE_NAME 自启失败或服务未启用。"
            ;;
        *)
            _warn "未针对 $OS ($OS_VERSION) 配置服务停止/禁用流程。"
            ;;
    esac

    _log "正在卸载 dante-server 软件包..."
    case "$OS" in
        centos|rhel)
            if command -v dnf &> /dev/null; then
                sudo dnf remove -y dante-server
            else
                sudo yum remove -y dante-server
            fi
            ;;
        debian|ubuntu)
            sudo apt-get purge -y dante-server # purge 会尝试移除配置文件
            sudo apt-get autoremove -y # 移除不再需要的依赖
            ;;
        alpine)
            sudo apk del dante-server
            ;;
        *)
            _error "未针对 $OS ($OS_VERSION) 配置软件包卸载流程。"
            ;;
    esac

    if [ -f "$CONFIG_FILE" ]; then
        read -p "配置文件 $CONFIG_FILE 似乎仍然存在。是否删除它? (yes/no): " del_config
        if [[ "${del_config,,}" == "yes" ]]; then
            sudo rm -f "$CONFIG_FILE"
            _log "配置文件 $CONFIG_FILE 已删除。"
        else
            _log "配置文件 $CONFIG_FILE 已保留。"
        fi
    fi
    # 日志文件等其他清理可以根据需要添加，例如 /var/log/${SERVICE_NAME}.log

    _log "Dante SOCKS5 服务器卸载完成。"
    _warn "注意：通过此脚本创建的系统用户 (用于SOCKS5认证的) 不会自动删除。"
    _warn "您如果需要，请手动使用 '$0 deluser <username>' 或系统命令 'sudo userdel <username>' 来删除它们。"
}


# 主函数，处理命令行参数
_main() {
    _check_root
    _detect_os # 执行OS检测以确定SERVICE_NAME等变量

    if [ "$#" -eq 0 ]; then
        echo "🚀 Dante SOCKS5 服务器管理脚本 🚀"
        echo "用法: $0 <操作>"
        echo ""
        echo "操作选项:"
        echo "  install      - 🚀 一键安装并配置 Dante SOCKS5 服务器 (推荐首次使用)"
        echo "  adduser      - 👤 添加一个新的 SOCKS5 用户 (需Dante已安装)"
        echo "  deluser      - 🗑️ 删除一个已存在的 SOCKS5 用户 (需Dante已安装)"
        echo "  restart      - 🔄 重启 Dante SOCKS5 服务 (需Dante已安装)"
        echo "  status       - 📊 显示 Dante SOCKS5 服务的当前状态 (需Dante已安装)"
        echo "  uninstall    - 🧹 卸载 Dante SOCKS5 服务器"
        echo ""
        echo "示例:"
        echo "  sudo $0 install        # 执行安装流程"
        echo "  sudo $0 adduser        # 添加用户"
        echo "  sudo $0 status         # 查看状态"
        exit 1
    fi

    action=$1
    shift # 移除第一个参数 (操作名)，方便后续参数传递给函数 (如果需要)

    # 在执行具体操作前，再次确保SERVICE_NAME 和 CONFIG_FILE 根据检测到的OS是正确的
    # (主要针对Alpine可能使用sockd的情况)
    if [[ "$OS" == "alpine" ]] && command -v sockd &> /dev/null && ! command -v danted &> /dev/null; then
        SERVICE_NAME="sockd"
        CONFIG_FILE="/etc/sockd.conf"
    fi


    case "$action" in
        install)
            _install_dante
            ;;
        adduser)
            if ! [ -f "$CONFIG_FILE" ] && ! _is_service_active ; then # 简单检查
                _error "Dante 服务似乎未安装或未正确配置 (未找到配置文件 $CONFIG_FILE 或服务 $SERVICE_NAME 未运行)。请先运行 'install' 操作。"
            fi
            _add_user
            _log "用户已添加/更新。Dante 服务通常会即时识别系统用户的更改。如果遇到问题，可尝试重启服务: sudo $0 restart"
            ;;
        deluser)
            if ! [ -f "$CONFIG_FILE" ] && ! _is_service_active ; then
                _error "Dante 服务似乎未安装或未正确配置。请先运行 'install' 操作。"
            fi
            _delete_user
            _log "用户已删除。建议重启服务以确保更改完全生效: sudo $0 restart"
            ;;
        restart)
            if ! [ -f "$CONFIG_FILE" ] && ! _is_service_active && ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service" ; then
                _error "Dante 服务似乎未安装或未正确配置。请先运行 'install' 操作。"
            fi
            _restart_service
            ;;
        status)
            # 状态检查可以更宽容，即使配置文件不存在，也尝试检查服务本身
            _show_status
            ;;
        uninstall)
            _uninstall_dante
            ;;
        *)
            _error "无效的操作: '$action'。有效操作见 '$0' 帮助信息。"
            ;;
    esac
}

# 使用所有脚本参数运行主函数
_main "$@"
