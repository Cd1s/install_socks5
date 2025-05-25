# SOCKS5 Proxy Server Installer

一个基于 sing-box 的 SOCKS5 代理服务器一键安装脚本，支持多种 Linux 发行版。

## 特性

- 🚀 **一键安装**: 简单快速的安装过程
- 🔐 **用户认证**: 支持用户名密码认证（可选）
- 🔧 **端口自定义**: 可以自定义监听端口
- 🗑️ **完整卸载**: 支持完全卸载和清理
- 🔄 **开机自启**: 自动配置系统服务开机启动
- 📊 **状态监控**: 实时查看服务状态和连接信息
- 🌍 **多系统支持**: 支持主流 Linux 发行版

## 支持的操作系统

- ✅ **CentOS** 7/8/9
- ✅ **RHEL** (Red Hat Enterprise Linux)
- ✅ **Rocky Linux**
- ✅ **AlmaLinux**
- ✅ **Debian** 9/10/11/12
- ✅ **Ubuntu** 18.04/20.04/22.04/24.04
- ✅ **Alpine Linux** 3.x

## 系统要求

- Root 权限
- 网络连接（用于下载 sing-box）
- 基本系统工具（curl, wget, tar, unzip）

## 快速开始

### 方法一：交互式安装

```bash
# 下载脚本
wget -O install_socks5.sh https://raw.githubusercontent.com/Cd1s/install_socks5/refs/heads/main/socks5_dante.sh

# 添加执行权限
chmod +x install_socks5.sh

# 运行脚本（交互式菜单）
sudo ./install_socks5.sh
```

### 方法二：命令行安装

```bash
# 直接安装
sudo ./install_socks5.sh install

# 卸载
sudo ./install_socks5.sh uninstall

# 查看状态
sudo ./install_socks5.sh status

# 重启服务
sudo ./install_socks5.sh restart

# 显示连接信息
sudo ./install_socks5.sh info
```

### 方法三：一行命令安装

```bash
curl -fsSL https://raw.githubusercontent.com/Cd1s/install_socks5/refs/heads/main/socks5_dante.sh | sudo bash -s install
```

## 使用说明

### 安装过程

1. 运行脚本后选择 "1. Install SOCKS5 Proxy"
2. 设置监听端口（默认：1080）
3. 选择是否启用用户认证
4. 如果启用认证，输入用户名和密码
5. 脚本会自动完成安装和配置

### 配置文件

- **配置目录**: `/etc/sing-box/`
- **配置文件**: `/etc/sing-box/config.json`
- **二进制文件**: `/usr/local/bin/sing-box`
- **服务名称**: `sing-box`

### 服务管理

```bash
# 启动服务
sudo systemctl start sing-box      # systemd 系统
sudo rc-service sing-box start     # Alpine (OpenRC)

# 停止服务
sudo systemctl stop sing-box       # systemd 系统
sudo rc-service sing-box stop      # Alpine (OpenRC)

# 重启服务
sudo systemctl restart sing-box    # systemd 系统
sudo rc-service sing-box restart   # Alpine (OpenRC)

# 查看状态
sudo systemctl status sing-box     # systemd 系统
sudo rc-service sing-box status    # Alpine (OpenRC)

# 查看日志
sudo journalctl -u sing-box -f     # systemd 系统
sudo tail -f /var/log/messages      # Alpine
```

## 客户端配置

### 无认证配置

```
类型: SOCKS5
服务器: YOUR_SERVER_IP
端口: 1080
用户名: (留空)
密码: (留空)
```

### 带认证配置

```
类型: SOCKS5
服务器: YOUR_SERVER_IP
端口: 1080
用户名: your_username
密码: your_password
```

### 连接 URL 格式

```bash
# 无认证
socks5://YOUR_SERVER_IP:1080

# 带认证
socks5://username:password@YOUR_SERVER_IP:1080
```

## 测试连接

### 使用 curl 测试

```bash
# 无认证
curl --proxy socks5://YOUR_SERVER_IP:1080 https://ipinfo.io/ip

# 带认证
curl --proxy socks5://username:password@YOUR_SERVER_IP:1080 https://ipinfo.io/ip
```

### 使用 Python 测试

```python
import requests

# 设置代理
proxies = {
    'http': 'socks5://username:password@YOUR_SERVER_IP:1080',
    'https': 'socks5://username:password@YOUR_SERVER_IP:1080'
}

# 测试连接
response = requests.get('https://ipinfo.io/ip', proxies=proxies)
print(f"Your IP through proxy: {response.text.strip()}")
```

## 常见问题

### Q: 安装失败，提示权限不足
A: 请确保使用 root 权限运行脚本：`sudo ./install_socks5.sh`

### Q: 无法连接到代理服务器
A: 检查以下几点：
- 防火墙是否开放了相应端口
- 服务是否正常运行：`sudo systemctl status sing-box`
- 配置文件是否正确：`cat /etc/sing-box/config.json`

### Q: 如何修改端口或认证信息？
A: 重新运行安装脚本，选择重新安装即可修改配置

### Q: 如何完全卸载？
A: 运行 `sudo ./install_socks5.sh uninstall` 或在菜单中选择卸载选项

### Q: Alpine Linux 下服务无法启动
A: 确保已安装 OpenRC：`apk add openrc`

## 防火墙配置

### CentOS/RHEL (firewalld)

```bash
# 开放端口
sudo firewall-cmd --permanent --add-port=1080/tcp
sudo firewall-cmd --reload
```

### Ubuntu/Debian (ufw)

```bash
# 开放端口
sudo ufw allow 1080/tcp
```

### iptables

```bash
# 开放端口
sudo iptables -A INPUT -p tcp --dport 1080 -j ACCEPT
```

## 安全建议

1. **修改默认端口**: 不要使用默认的 1080 端口
2. **启用认证**: 强烈建议启用用户名密码认证
3. **强密码**: 使用复杂的密码
4. **防火墙配置**: 只允许需要的 IP 访问
5. **定期更新**: 定期更新 sing-box 到最新版本

## 目录结构

```
/etc/sing-box/
├── config.json              # 主配置文件

/usr/local/bin/
├── sing-box                  # sing-box 二进制文件

/etc/systemd/system/          # systemd 系统
├── sing-box.service          # 服务文件

/etc/init.d/                  # OpenRC 系统 (Alpine)
├── sing-box                  # 服务脚本
```

## 技术支持

如果您遇到问题，请：

1. 检查服务状态：`sudo ./install_socks5.sh status`
2. 查看日志：`sudo journalctl -u sing-box -f`
3. 验证配置：`cat /etc/sing-box/config.json`

## 许可证

本项目基于 MIT 许可证开源。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持 CentOS, Debian, Ubuntu, Alpine
- 支持用户认证和端口自定义
- 支持开机自启和服务管理
