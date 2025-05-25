# SOCKS5 一键安装脚本

## 📋 项目简介

支持多种Linux系统的SOCKS5代理服务器一键安装脚本，2025年版本，基于3proxy构建。

## 🎯 支持系统

- **CentOS** (7.x / 8.x / 9.x)
- **Ubuntu** (18.04 / 20.04 / 22.04 / 24.04)
- **Debian** (9 / 10 / 11 / 12)
- **Alpine Linux** (3.x)

## 🚀 一键安装

### 方法1: 在线安装 (推荐)

```bash
# 一键安装命令
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install_socks5.sh)
```

### 方法2: 手动安装

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/socks5_install.sh

# 2. 运行安装
chmod +x socks5_install.sh
sudo ./socks5_install.sh
```

## 📱 安装过程

运行脚本后会出现交互式菜单：

1. **选择操作** - 选择"1. 安装 SOCKS5 代理"
2. **设置用户名** - 默认为 `admin`，可自定义
3. **设置密码** - 输入强密码（必填）
4. **设置端口** - 默认为 `1080`，可自定义
5. **确认配置** - 检查设置是否正确
6. **自动安装** - 脚本自动完成所有配置

## 🔧 功能特性

- ✅ **多系统支持** - 自动检测系统类型
- ✅ **一键安装** - 无需手动编译配置
- ✅ **安全认证** - 用户名密码保护
- ✅ **防火墙配置** - 自动开放端口
- ✅ **系统服务** - systemd 集成，支持开机自启
- ✅ **日志记录** - 详细的访问日志
- ✅ **完整卸载** - 一键清理所有文件

## 🛠 服务管理

安装完成后，可使用以下命令管理服务：

```bash
# 查看服务状态
systemctl status 3proxy

# 启动/停止/重启服务
systemctl start 3proxy
systemctl stop 3proxy
systemctl restart 3proxy

# 查看日志
journalctl -u 3proxy -f
tail -f /var/log/3proxy/3proxy.log
```

## 🔗 客户端配置

安装完成后会显示连接信息：

```
服务器IP: YOUR_SERVER_IP
端口: 1080
用户名: admin
密码: YOUR_PASSWORD
协议: SOCKS5
```

### 常用客户端

- **Windows**: Proxifier, SocksCap64
- **macOS**: ClashX, Surge
- **Android**: Postern, Drony
- **iOS**: Surge, Shadowrocket

## 🗑️ 卸载服务

如需完全卸载SOCKS5服务，运行主脚本选择卸载：

```bash
sudo ./socks5_install.sh
# 然后选择 "2. 卸载 SOCKS5 代理"
```

## 🐛 常见问题

### 1. 安装失败
- 确保有root权限
- 检查网络连接
- 确认系统支持

### 2. 无法连接
- 检查防火墙设置
- 确认服务状态: `systemctl status 3proxy`
- 查看日志: `journalctl -u 3proxy`

### 3. 端口被占用
脚本会自动检测端口冲突，选择其他可用端口即可。

## 📞 支持

如有问题，请提供：
1. 系统版本: `cat /etc/os-release`
2. 错误信息: `journalctl -u 3proxy -n 20`
3. 服务状态: `systemctl status 3proxy`

## ⚠️ 免责声明

本脚本仅供学习和合法用途，用户需遵守当地法律法规。

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**版本**: v1.0.0  
**更新**: 2025-05-25  
**支持**: CentOS/Ubuntu/Debian/Alpine
