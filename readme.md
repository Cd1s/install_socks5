# SOCKS5代理一键安装脚本

基于Dante Server的SOCKS5代理一键安装脚本，支持CentOS/Debian/Ubuntu/Alpine。

## 一键安装

```bash
wget https://raw.githubusercontent.com/Cd1s/install_socks5/main/socks5_dante.sh && chmod +x socks5_dante.sh && ./socks5_dante.sh
```

## 功能

- 安装/卸载 SOCKS5代理
- 用户名密码认证
- 查看服务状态
- 自动防火墙配置

## 使用说明

运行脚本后会显示交互式菜单：

```
================================
    SOCKS5代理管理脚本
    基于Dante Server
================================

1. 安装SOCKS5代理
2. 卸载SOCKS5代理
3. 查看运行状态
0. 退出脚本

请选择操作 [0-3]:
```

### 安装选项

1. **端口设置**：默认1080，可自定义
2. **认证方式**：
   - 无认证：任何人都可以使用
   - 用户名密码认证：更安全的访问控制

### 配置示例

**无认证配置：**
- 端口：1080
- 认证：无需认证
- 使用：直接连接IP:1080

**用户认证配置：**
- 端口：1080
- 用户名：user123
- 密码：pass456
- 使用：连接时输入用户名密码

## 服务管理

### SystemD系统（CentOS/Debian/Ubuntu）

```bash
# 启动服务
systemctl start sockd

# 停止服务
systemctl stop sockd

# 重启服务
systemctl restart sockd

# 查看状态
systemctl status sockd

# 开机自启
systemctl enable sockd

# 禁用自启
systemctl disable sockd
```

### OpenRC系统（Alpine Linux）

```bash
# 启动服务
rc-service sockd start

# 停止服务
rc-service sockd stop

# 重启服务
rc-service sockd restart

# 查看状态
rc-service sockd status

# 开机自启
rc-update add sockd default

# 禁用自启
rc-update del sockd default
```

## 配置文件

- **配置文件位置**：`/etc/sockd.conf`
- **服务名称**：`sockd`

## 客户端连接

### 浏览器设置

1. 打开浏览器代理设置
2. 选择SOCKS代理
3. 地址：服务器IP
4. 端口：设置的端口（默认1080）
5. 类型：SOCKS5
6. 如有认证，输入用户名密码

### 命令行测试

```bash
# 测试连接（无认证）
curl --socks5 服务器IP:端口 http://ipinfo.io

# 测试连接（用户认证）
curl --socks5 用户名:密码@服务器IP:端口 http://ipinfo.io
```

## 防火墙配置

脚本会自动配置防火墙规则，支持：

- **UFW**（Ubuntu默认）
- **firewalld**（CentOS默认）
- **iptables**（通用）

手动配置示例：

```bash
# UFW
ufw allow 1080/tcp

# firewalld
firewall-cmd --permanent --add-port=1080/tcp
firewall-cmd --reload

# iptables
iptables -I INPUT -p tcp --dport 1080 -j ACCEPT
```

## 故障排除

### 常见问题

1. **服务启动失败**
   ```bash
   # 查看详细错误
   journalctl -u sockd -f
   ```

2. **端口被占用**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :1080
   ```

3. **防火墙问题**
   ```bash
   # 临时关闭防火墙测试
   systemctl stop firewalld  # CentOS
   ufw disable              # Ubuntu
   ```

4. **权限问题**
   ```bash
   # 确保以root权限运行
   sudo ./dante_socks5.sh
   ```

### 日志查看

```bash
# 系统日志
tail -f /var/log/syslog | grep sockd

# SystemD日志
journalctl -u sockd -f

# 手动测试
sockd -D -f /etc/sockd.conf
```

## 安全建议

1. **使用强密码**：如果启用认证，请使用复杂密码
2. **限制访问**：考虑使用防火墙限制访问来源
3. **定期更新**：保持系统和软件包更新
4. **监控流量**：定期检查代理使用情况

## 许可证

MIT License

## 贡献

欢迎提交Issues和Pull Requests来改进这个脚本。

---

**注意**：此脚本仅供学习和合法用途使用，请遵守当地法律法规。
