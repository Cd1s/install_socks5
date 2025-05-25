#!/bin/bash

# SOCKS5 Proxy Server Installer using sing-box
# Support: CentOS, Debian/Ubuntu, Alpine Linux
# Author: Auto-generated script
# Date: $(date)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOCKS5_PORT=1080
USERNAME=""
PASSWORD=""
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_NAME="sing-box"
BINARY_PATH="/usr/local/bin/sing-box"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [[ -f /etc/debian_version ]]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [[ -f /etc/SuSe-release ]]; then
        OS=openSUSE
    elif [[ -f /etc/redhat-release ]]; then
        OS=Red\ Hat\ Enterprise\ Linux
        VER=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# Install dependencies based on OS
install_dependencies() {
    print_info "Installing dependencies..."
    
    case $OS in
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            yum update -y
            yum install -y curl wget unzip tar
            ;;
        *"Debian"*|*"Ubuntu"*)
            apt-get update
            apt-get install -y curl wget unzip tar
            ;;
        *"Alpine"*)
            apk update
            apk add curl wget unzip tar
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}

# Download and install sing-box
install_singbox() {
    print_info "Downloading and installing sing-box..."
    
    # Get system architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Get latest release version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        print_error "Failed to get latest version"
        exit 1
    fi
    
    # Download sing-box
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"
    
    print_info "Downloading sing-box ${LATEST_VERSION} for ${ARCH}..."
    wget -O /tmp/sing-box.tar.gz "$DOWNLOAD_URL"
    
    # Extract and install
    cd /tmp
    tar -xzf sing-box.tar.gz
    
    # Find the binary in the extracted directory
    EXTRACTED_DIR=$(tar -tzf sing-box.tar.gz | head -1 | cut -f1 -d"/")
    chmod +x "${EXTRACTED_DIR}/sing-box"
    mv "${EXTRACTED_DIR}/sing-box" "$BINARY_PATH"
    
    # Clean up
    rm -rf /tmp/sing-box.tar.gz /tmp/"$EXTRACTED_DIR"
    
    print_success "sing-box installed successfully"
}

# Create configuration directory
create_config_dir() {
    mkdir -p "$CONFIG_DIR"
    print_info "Configuration directory created: $CONFIG_DIR"
}

# Generate sing-box configuration
generate_config() {
    print_info "Generating sing-box configuration..."
    
    # Create config based on whether authentication is required
    if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
        cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": $SOCKS5_PORT,
      "users": [
        {
          "username": "$USERNAME",
          "password": "$PASSWORD"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    else
        cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": $SOCKS5_PORT
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    fi
    
    print_success "Configuration file created: $CONFIG_FILE"
}

# Create systemd service
create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=sing-box proxy server
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Type=simple
ExecStart=$BINARY_PATH run -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    print_success "Systemd service created and enabled"
}

# Create OpenRC service (for Alpine)
create_openrc_service() {
    print_info "Creating OpenRC service..."
    
    # Fix Alpine Linux specific issues
    if [[ "$OS" == *"Alpine"* ]]; then
        # Ensure required directories exist
        mkdir -p /var/run /var/log /tmp
        
        # Install required packages for Alpine
        apk add --no-cache openrc coreutils
        
        # Enable OpenRC
        if [ ! -f /run/openrc/softlevel ]; then
            openrc sysinit
            openrc boot
            openrc default
        fi
    fi
    
    cat > "/etc/init.d/${SERVICE_NAME}" << 'EOF'
#!/sbin/openrc-run

name="sing-box"
description="sing-box proxy server"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background="yes"
pidfile="/tmp/sing-box.pid"
start_stop_daemon_args="--make-pidfile"

depend() {
    need net
    use logger
}

start_pre() {
    # Ensure config file exists
    if [ ! -f "/etc/sing-box/config.json" ]; then
        eerror "Configuration file not found: /etc/sing-box/config.json"
        return 1
    fi
    
    # Create required directories
    mkdir -p /tmp /var/log
    
    # Test configuration
    ${command} check -c /etc/sing-box/config.json >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        eerror "Configuration validation failed"
        return 1
    fi
}

start() {
    ebegin "Starting $name"
    start-stop-daemon --start --background --make-pidfile \
        --pidfile "$pidfile" --exec "$command" -- $command_args
    eend $?
}

stop() {
    ebegin "Stopping $name"
    start-stop-daemon --stop --pidfile "$pidfile"
    eend $?
}

reload() {
    ebegin "Reloading $name"
    if [ -f "$pidfile" ]; then
        kill -HUP $(cat $pidfile)
    fi
    eend $?
}
EOF

    chmod +x "/etc/init.d/${SERVICE_NAME}"
    
    # Add service to default runlevel
    rc-update add "$SERVICE_NAME" default
    
    print_success "OpenRC service created and enabled"
}

# Setup service based on init system
setup_service() {
    if command -v systemctl >/dev/null 2>&1; then
        create_systemd_service
    elif command -v rc-update >/dev/null 2>&1; then
        create_openrc_service
    else
        print_error "Unsupported init system"
        exit 1
    fi
}

# Start service
start_service() {
    print_info "Starting sing-box service..."
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start "$SERVICE_NAME"
        systemctl status "$SERVICE_NAME" --no-pager
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service "$SERVICE_NAME" start
    else
        print_error "Cannot start service: unsupported init system"
        exit 1
    fi
    
    print_success "sing-box service started successfully"
}

# Stop service
stop_service() {
    print_info "Stopping sing-box service..."
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service "$SERVICE_NAME" stop 2>/dev/null || true
    fi
}

# Remove sing-box
remove_singbox() {
    print_info "Removing sing-box..."
    
    # Stop service
    stop_service
    
    # Disable and remove service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
    elif command -v rc-update >/dev/null 2>&1; then
        rc-update del "$SERVICE_NAME" default 2>/dev/null || true
        rm -f "/etc/init.d/${SERVICE_NAME}"
    fi
    
    # Remove files
    rm -f "$BINARY_PATH"
    rm -rf "$CONFIG_DIR"
    
    print_success "sing-box removed successfully"
}

# Show status
show_status() {
    print_info "SOCKS5 Proxy Status:"
    echo "================================"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status "$SERVICE_NAME" --no-pager || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service "$SERVICE_NAME" status || true
    fi
    
    echo ""
    print_info "Configuration:"
    echo "  Port: $SOCKS5_PORT"
    echo "  Config file: $CONFIG_FILE"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        if grep -q "username" "$CONFIG_FILE"; then
            echo "  Authentication: Enabled"
        else
            echo "  Authentication: Disabled"
        fi
    fi
}

# Show connection info
show_connection_info() {
    local server_ip=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo ""
    print_success "SOCKS5 Proxy Server Information:"
    echo "================================"
    echo "Server IP: $server_ip"
    echo "Port: $SOCKS5_PORT"
    echo "Type: SOCKS5"
    
    if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
        echo "Username: $USERNAME"
        echo "Password: $PASSWORD"
        echo ""
        echo "Connection URL: socks5://$USERNAME:$PASSWORD@$server_ip:$SOCKS5_PORT"
    else
        echo "Authentication: None"
        echo ""
        echo "Connection URL: socks5://$server_ip:$SOCKS5_PORT"
    fi
    
    echo ""
    print_info "To test the proxy:"
    echo "  curl --proxy socks5://$server_ip:$SOCKS5_PORT https://ipinfo.io/ip"
}

# Main menu
show_menu() {
    clear
    echo "================================"
    echo "   SOCKS5 Proxy Manager"
    echo "   Powered by sing-box"
    echo "================================"
    echo "1. Install SOCKS5 Proxy"
    echo "2. Uninstall SOCKS5 Proxy"
    echo "3. Show Status"
    echo "4. Restart Service"
    echo "5. Show Connection Info"
    echo "6. Exit"
    echo "================================"
}

# Get user input for configuration
get_user_config() {
    echo ""
    read -p "Enter SOCKS5 port (default: 1080): " input_port
    SOCKS5_PORT=${input_port:-1080}
    
    echo ""
    read -p "Enable authentication? (y/n, default: n): " auth_choice
    
    if [[ "$auth_choice" =~ ^[Yy]$ ]]; then
        read -p "Enter username: " USERNAME
        read -s -p "Enter password: " PASSWORD
        echo ""
    fi
}

# Install process
install_process() {
    print_info "Starting SOCKS5 proxy installation..."
    
    # Check if already installed
    if [[ -f "$BINARY_PATH" ]]; then
        print_warning "sing-box is already installed"
        read -p "Do you want to reinstall? (y/n): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        remove_singbox
    fi
    
    get_user_config
    detect_os
    install_dependencies
    install_singbox
    create_config_dir
    generate_config
    setup_service
    start_service
    show_connection_info
}

# Main script logic
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Handle command line arguments
    case "${1:-}" in
        "install")
            install_process
            ;;
        "remove"|"uninstall")
            remove_singbox
            ;;
        "status")
            show_status
            ;;
        "restart")
            stop_service
            start_service
            ;;
        "info")
            show_connection_info
            ;;
        *)
            while true; do
                show_menu
                read -p "Please enter your choice [1-6]: " choice
                
                case $choice in
                    1)
                        install_process
                        read -p "Press Enter to continue..."
                        ;;
                    2)
                        remove_singbox
                        read -p "Press Enter to continue..."
                        ;;
                    3)
                        show_status
                        read -p "Press Enter to continue..."
                        ;;
                    4)
                        stop_service
                        start_service
                        read -p "Press Enter to continue..."
                        ;;
                    5)
                        show_connection_info
                        read -p "Press Enter to continue..."
                        ;;
                    6)
                        print_success "Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option. Please try again."
                        sleep 2
                        ;;
                esac
            done
            ;;
    esac
}

# Run main function
main "$@"
