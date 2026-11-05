# Agent 自托管工具箱（零公网端口 / 重启免扫码 / 掉线自愈）

一台 2 GB 内存的云主机上跑 agent 运行时，本地 Windows 负责记忆与素材。这套脚本解决的是
**部署与活着**的问题：不开公网端口、宿主机重启后不掉登录、进程挂了自己起来。

> 全部文件是**脱敏后的可运行模板**：真实主机、账号、票据一律用 `${...}` 占位。
> 生产版脚本写死了这些信息，**不在本仓库**。

## 能力位

| 能力 | 关键结论 | 代码 |
|---|---|---|
| 零公网端口 | 用 Tailscale 把本机服务借进 tailnet，不暴露公网 | `deploy/tailscale-only.sh` |
| DNS 不被劫持 | Tailscale 必须 `--accept-dns=false`，否则内网源解析到不可达地址 | 同上 |
| 重启免扫码 | NapCat 快速登录**只认环境变量 `ACCOUNT`**；镜像名后的 `-q` 会进 `Config.Cmd` 但被 entrypoint 完全忽略 | `deploy/pin-quicklogin.sh` |
| 常驻 | systemd 必须显式 `Environment=HOME=...`，否则运行时找不到家目录 | `systemd/*.service` |
| 开机自检 | timer 每小时第 7 分钟，`Persistent=true` 补跑 | `systemd/agent-health.timer` |
| 体检失败不重启风暴 | `SuccessExitStatus=0 1`，体检失败不触发 restart 循环 | `systemd/agent-health.service` |
| 掉线自愈 | 看门狗按连续掉线分钟数判断，且有每小时重启上限 | `tools/healthcheck.py` |

## 三条踩过的坑（都是实测，不是文档抄的）

1. **装 systemd 之前必须先杀掉手工起的裸进程**，否则 PID 锁冲突 → 服务无限重启循环，
   表现为 `NRestarts` 疯涨、状态一直 `activating`。
2. **容器能 `docker start` 就别重建**。重建会清空进程内登录态，直接掉回二维码模式；
   真要重建必须把 `ACCOUNT` 写进启动命令。
3. **apt 源要换成可达镜像**。默认内网源会解析到 CGNAT 地址，装包直接超时。

## 部署顺序

```bash
# 1. 基础环境（Node >= 22、运行时）
# 2. 消息端容器，务必带 ACCOUNT
ACCOUNT=<your_uin> bash deploy/pin-quicklogin.sh
# 3. 组网，不开端口
bash deploy/tailscale-only.sh
# 4. systemd 三件套
cp systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now agent-bridge.service agent-health.timer
# 5. 验证
systemctl is-active agent-bridge && python3 tools/healthcheck.py
```

## 退出码约定

`pin-quicklogin.sh`：`0` 已登录 / `2` 需要扫码 / `1` 其他失败。
看门狗把它当三态用，`2` 才走人工扫码流程。

> **归属声明**：本仓库只收录**从零写的独立模块**。QQ 桥接层基于上游
> `Derpyu520/qq-bridge`（MIT），DSH 运行时由 DeepSeek 提供，**本仓库不包含它们的任何代码**。
> 文档里提到这些组件仅为说明运行环境，并已在 `docs/ORIGINAL_WORK.md` 逐项署名。

## 许可

MIT，见 [LICENSE](LICENSE)。
