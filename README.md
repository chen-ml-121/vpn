# Server Codex VPN

这套流程让服务器上的 VS Code Remote Codex 使用服务器本机的 Mihomo 代理。
代理只监听 `127.0.0.1:17890`，不启用 TUN，不修改系统路由，因此训练、推理和 SSH
等其他程序继续使用原网络。

仓库不包含 Clash 订阅、节点密码或 API Key。真实配置文件只保存在本机和服务器的
`/root/codex-proxy.yaml`。

## 一次性准备

本机需要存在：

```text
~/.ssh/id_ed25519
~/.config/clash-verge/profiles/rvTa8DiFWjst.yaml
```

服务器信息：

```text
Host: 115.191.61.28
SSH port: 33127
User: root
```

如果 Clash 配置文件名不同，把下面命令中的路径替换成实际路径。

## 容器重建后的完整流程

### 1. 从本机上传私有 Clash 配置

在**本机终端**执行：

```bash
scp -P 33127 -i ~/.ssh/id_ed25519 \
  ~/.config/clash-verge/profiles/rvTa8DiFWjst.yaml \
  root@115.191.61.28:/root/codex-proxy.yaml
```

确认上传成功：

```bash
ssh -p 33127 -i ~/.ssh/id_ed25519 root@115.191.61.28 \
  'stat -c "%a %s %n" /root/codex-proxy.yaml'
```

### 2. 登录服务器并克隆安装仓库

```bash
ssh -p 33127 -i ~/.ssh/id_ed25519 root@115.191.61.28
```

在服务器中执行：

```bash
rm -rf /root/vpn-installer
git clone https://github.com/chen-ml-121/vpn.git /root/vpn-installer
cd /root/vpn-installer
bash install.sh /root/codex-proxy.yaml
```

安装脚本会自动：

- 创建 `/root/vpn/bin`、`config`、`logs`、`run`；
- 复制私有配置到 `/root/vpn/config/original.yaml`；
- 生成仅本机监听的 `/root/vpn/config/config.yaml`；
- 安装并校验 Mihomo v1.19.32；
- 下载 GeoIP 数据库 `geoip.metadb`；
- 启动本机代理；
- 给远程 VS Code Codex 二进制安装代理包装器。

### 3. 检查代理是否运行

```bash
ss -lnt | grep -E ':17890|:19090'
```

应看到：

```text
127.0.0.1:17890
127.0.0.1:19090
```

查看当前代理组节点：

```bash
curl http://127.0.0.1:19090/proxies/Research%20%2B%20AI \
  | grep -o '"now":"[^"]*"'
```

切换节点示例：

```bash
curl --noproxy '*' -X PUT \
  http://127.0.0.1:19090/proxies/Research%20%2B%20AI \
  -H 'Content-Type: application/json' \
  -d '{"name":"US Fixed IP"}'
```

节点名称不等于实际出口地区；登录报 `Country, region, or territory not supported` 时，
需要换成实际被 OpenAI 接受的出口节点。

### 4. 重新加载本机 VS Code

本机打开连接服务器的 Remote SSH 窗口，执行命令面板：

```text
Developer: Reload Window
```

然后在 Codex 中选择 `Sign in with ChatGPT`。不要使用第三方 API Key 请求
`api.openai.com`。

### 5. 验证 Codex 确实走代理

在服务器执行：

```bash
pgrep -af codex
for p in $(pgrep -x codex); do
  echo "PID=$p"
  tr '\0' '\n' < /proc/$p/environ \
    | grep -E '^(HTTP|HTTPS|ALL|NO)_PROXY='
done
```

应该看到：

```text
HTTP_PROXY=http://127.0.0.1:17890
HTTPS_PROXY=http://127.0.0.1:17890
ALL_PROXY=http://127.0.0.1:17890
```

如果没有这些变量，说明远程扩展没有重新启动，重新执行 `Developer: Reload Window`。

## 代理启动脚本

容器重启但文件仍存在时，只需：

```bash
bash /root/vpn/start-codex-vpn.sh
```

日志：

```text
/root/vpn/logs/mihomo.log
```

如果日志显示 `Can't find MMDB` 或无法下载 `geoip.metadb`，重新运行仓库安装脚本，
或将已保存的 GeoIP 文件放回：

```text
/root/vpn/config/geoip.metadb
```

## 重要安全事项

- 不要提交 `rvTa8DiFWjst.yaml`、`original.yaml`、`geoip.metadb` 或任何订阅链接。
- 不要把 API Key、节点密码和 GitHub Token 写入 README 或命令历史。
- 不要把代理变量写进 `/etc/environment` 或全局 shell 配置。
- `rm -rf /root/vpn-installer` 只删除安装器，不删除运行中的 `/root/vpn`。
