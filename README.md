# Claude 1M Context Unlock · 一键解除桌面端 200k 上下文限制

<p align="center">
  <img src="assets/banner.jpg" alt="Claude 1M Context Unlock" width="180">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Angelica-Lin/claude-1m-context-unlock?color=blue" alt="License"></a>
  <a href="https://github.com/Angelica-Lin/claude-1m-context-unlock/releases/latest"><img src="https://img.shields.io/github/v/release/Angelica-Lin/claude-1m-context-unlock" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/deps-none-brightgreen" alt="No dependencies">
</p>

> 🌐 **English version: [README.en.md](README.en.md)**
>
> 🤖 **用 AI / Claude Code 自动安装？** 把整个 zip 拖进 Claude Code，让它读 [AGENTS.md](AGENTS.md) 即可全自动完成。

> ## ⚠️ 重要声明
>
> **本工具包是 "Vibe Coding"（AI 辅助随手编码）的产物**，由 AI 协助生成、经基本测试，但**不保证在你的环境中绝对无误**。使用前请务必：
> - **先备份你的 `~/.claude/settings.json`**（工具会自动备份成 `settings.json.bak.<时间戳>`，但请你自己也另存一份到别处，双保险）。
> - **理解你在做什么**：它会往 `settings.json` 加两个键并设两个用户环境变量。看不懂就先读完下面的说明，或找懂的人确认。
> - **自担风险使用**：作者/分发者对任何数据丢失、配置损坏、账单变化或其它后果**不承担责任**。重要数据请确保有独立备份。
> - 这不是 Anthropic 官方工具，与 Anthropic 无关，不附带任何担保。

> **一句话上手** — 双击运行（Windows）或 `./install-mac-linux.sh`（Mac/Linux），选 `1) Install`，**完全退出并重开桌面版**。完成。

---

## 这是什么？

新版 Claude 桌面端有一道门禁（`longContext1mCreditsBlocked`）：即使你的模型本应支持 **1M（100 万 token）上下文**，客户端也会从代理响应判定「该账号无 1M 额度」，把上下文**强行截回 200k**。表现就是 `/context` 或左下角进度条的分母只有 `200.0k`，而不是 `1000.0k`。

本工具利用客户端里一条**更高优先级的覆盖路径**绕过这道门禁，把分母恢复成 1M。

它怎么做到的（两层，互为兜底）：
1. 往你的 `~/.claude/settings.json` 的 `env` 块写入**两个键**（缺一不可）：
   ```json
   "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
   "DISABLE_COMPACT": "1"
   ```
   Claude 启动时会把它们合并进进程环境——**这是最可靠的一层，桌面版和 CLI 都生效**。
2. 同时把这两个键设成用户级环境变量（Windows）/ 往 shell rc 追加 export（Mac/Linux）作为第二层兜底（覆盖从终端启动的进程）。

**机制原理**：客户端代码里，当 `DISABLE_COMPACT` 为真**且** `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 有值时，会抢在门禁判断**之前**就 `return` 这个上下文上限值，于是那道把 1M 截回 200k 的门禁代码根本走不到。两个键缺任何一个，覆盖路径都不成立。

✅ 不需要管理员/root · 不需要 Node.js · 不打补丁、不动 Claude 二进制 · 不碰你的 token 或中转站配置。

---

## 🟥 必读：唯一的代价是关闭 auto-compact

绕过门禁是靠 `DISABLE_COMPACT=1` 实现的，而它的副作用就是**彻底关闭 auto-compact（自动压缩/总结）**：

- 上下文写满后**不会再自动总结**腾出空间；
- 你需要**手动运行 `/compact`**，或者**开一个新会话**。

这是解锁 1M 的**必要代价**，不是 bug。对长会话用户来说，换来的是 5 倍的上下文空间（200k → 1M），通常很划算；但你必须知道自动压缩没了。`3) Rollback` 会同时恢复 auto-compact。

---

## 🚀 懒人流程（不想看原理，照做就行）

**只想搞定、不关心怎么实现？三步：**

1. **解压**：把 zip 里的**所有文件**解压到同一个文件夹（别只解压单个文件）。
2. **运行**：
   - **Windows** → 双击 **`install-windows.bat`** → 输入 `1` 回车。
   - **macOS / Linux** → 终端里 `cd` 到该文件夹，运行 `chmod +x install-mac-linux.sh && ./install-mac-linux.sh` → 输入 `1` 回车。
3. **完全退出并重开桌面版**（托盘图标右键 → 退出，不是只关窗口；CLI 则新开一个终端）。**完成。**

> 想确认成功？重开后在桌面版里输入 `/context`，看分母：`1000.0k` = 成功，`200.0k` = 没生效（见下方「失败排查」）。
>
> 用 AI 更省事：把 zip 拖进 Claude Code，让它读 [AGENTS.md](AGENTS.md)，它会自动跑完上面这些。

---

## ⚠️ 一句诚实的话

本工具**只负责把那两个键写进配置 / 环境变量**，让客户端走上覆盖路径。**能否真的解锁 1M，还取决于：**

| 前提 | 说明 |
|---|---|
| 你的渠道/账号本身支持 1M | 官方 1M 需要对应额度；第三方中转站需后端真的转发 `context-1m` 能力。本工具不会凭空给你 1M，只是解开客户端那道**额外的**截断。 |
| 你的桌面版版本里仍有这条覆盖路径 | 这是利用客户端现有逻辑，**未来某次更新可能改掉**。若失效见下方「失败排查」。 |

如果重启后分母仍是 `200.0k`，多半是上面某条不满足。设置本身无害（不支持时只是没效果）。

---

## 安装

### Windows

1. 把 zip **全部文件**解压到同一个文件夹。
2. 双击 **`install-windows.bat`**。
3. 在弹出的窗口里输入 `1` 回车（Install）。
4. 按提示**完全退出并重开桌面版**。

> 不会弹"是否以管理员运行"，也不需要改 PowerShell 执行策略——`.bat` 已用 `-ExecutionPolicy Bypass` 处理好。

### macOS / Linux

```bash
chmod +x install-mac-linux.sh
./install-mac-linux.sh
```
然后输入 `1` 回车。改 JSON 用系统自带的 `python3`（缺失时用 `perl` 兜底）。

> 桌面版（GUI）不读 shell 配置文件，所以它靠 `settings.json` 那一层生效——本工具已经帮你写好。

---

## 验证是否生效

**方法一（最直接，唯一真正可信的判定）：**
重启桌面版后，在对话框输入 `/context`（或看左下角进度条分母）：
- 分母显示 **`1000.0k`** → ✅ 成功，1M 已解锁。
- 分母还是 **`200.0k`** → ❌ 没生效，见「失败排查」。

**方法二（查配置，零依赖）：**
再次运行安装器，选 `2) Status`，看 **VERDICT** 行：`ACTIVE`（两键齐全）才对。注意这只确认**配置写对了**，不等于桌面版一定解锁——最终还是以方法一的分母为准。

**方法三（可选，需 Node.js）：**
独立纯读取脚本：`node check-1m-context.js`，报告两个键是否齐全。同样只查配置层。

---

## 回滚

运行安装器 → 选 `3) Rollback`。它会从 `settings.json` 删掉那两个键，并清掉用户环境变量 / shell rc 里对应的行（**同时恢复 auto-compact**）。每次写入前都会自动备份 `settings.json.bak.<时间戳>`。

---

## 失败排查（重启后分母仍是 200k）

按可能性从高到低试：

1. **没有真正重启**：必须**完全退出**桌面版进程（托盘右键 → 退出），不是只关窗口。env 只在启动时读。
2. **只设了一个键**：跑 `2) Status` 看 VERDICT 是不是 `ACTIVE`；若是 `INCOMPLETE — missing XXX`，说明少了一个键，重跑 `1) Install`。两键**缺一不可**。
3. **客户端改用严格 bool 解析**：某次升级后可能不再接受字面量 `"1"`。手动把 `settings.json` 里两个值都改成 `"true"` 再重启试：
   ```json
   "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
   "DISABLE_COMPACT": "true"
   ```
4. **渠道/账号本身就没有 1M**：本工具只解客户端那道额外截断，给不了你账号没有的额度。确认你的官方额度或中转站后端是否真支持 1M（官方需 `anthropic-beta: context-1m-2025-08-07`，部分中转站用 `?beta=true`）。
5. **这条覆盖路径被新版移除**：如果以上都对、配置也确认写进去了还是 200k，可能是客户端更新堵了这条路。可考虑锁定一个已知可用的桌面版版本、关闭自动更新。

---

## 常见问题

**Q: 双击 `.bat` 闪一下就关 / 提示"无法加载，因为在此系统上禁止运行脚本"？**
多数情况下 `.bat` 里的 `-ExecutionPolicy Bypass` 已绕过限制。如果你的电脑被**企业组策略（Group Policy）**强制锁死了执行策略，`Bypass` 也会失效。应对：
- 在 PowerShell 里直接跑：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . '完整路径\install-windows.ps1' -Action install }"
  ```
- 或：本工具只是往 `~/.claude/settings.json` 的 `env` 块加两行键，你也可以**手动**用记事本加（参考 `example-settings.json`）。
- 公司电脑若彻底锁死，联系 IT 或换台个人电脑。

**Q: 改完没生效？**
环境变量只对**之后新启动**的进程生效。桌面版要**完全退出再重开**（不是只关窗口）；CLI 要**新开终端**。然后用 `/context` 看分母。

**Q: 关了 auto-compact 之后上下文满了怎么办？**
手动运行 `/compact` 压缩，或开一个新会话。这是开启 1M 后的常规操作。

**Q: 我用的是 CLI，不是桌面版，也需要这个吗？**
CLI 直连官方/渠道时，1M 通常靠模型名后缀 `[1M]` 或 beta 头直接生效，多半不需要本工具。本工具主要针对**桌面端被门禁截回 200k** 的情况。

---

## 涉及的两个变量

| 变量 | 作用 |
|---|---|
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | 显式指定上下文 token 上限。本工具写 `1000000`（=1M）。 |
| `DISABLE_COMPACT` | 关闭 auto-compact。**它是覆盖路径的触发开关**，缺它则门禁不会被绕过。真值：`1`/`true`/`yes`/`on`，本工具写 `1`。副作用见上文「必读」。 |

两个键**缺一不可**——只有同时满足，客户端才会在门禁之前 return 上下文上限。

---

## 文件清单

| 文件 | 说明 |
|---|---|
| `install-windows.bat` | Windows 双击入口 |
| `install-windows.ps1` | Windows 实际逻辑（PowerShell 5.1+） |
| `install-mac-linux.sh` | macOS / Linux 安装器 |
| `check-1m-context.js` | 可选 Node 纯读取校验（不联网） |
| `example-settings.json` | 脱敏示例（勿直接用） |
| `AGENTS.md` | 给 AI agent 看的自动执行指令 |
| `README.md` | 本文件（中文） |
| `README.en.md` | 英文版 |
| `CHANGELOG.md` | 版本变更记录 |
| `assets/banner.jpg` | 展示图 |

---

## 安全说明

- **绝不覆盖坏 JSON**：解析失败立即中止，原文件不动。
- **写前必备份**：`settings.json.bak.<时间戳>`。
- **缺失则新建**：没有 `settings.json` 会建一个最小合法文件。
- **保留你的其它设置**：只增/删那两个键，`theme`、`ANTHROPIC_BASE_URL`、token 等原样保留。
- **尊重 `CLAUDE_CONFIG_DIR`**：设了就用它，不碰默认 `~/.claude`。
- **不碰 token / 中转站配置**：解门禁不需要动这些。

---

## 版本

- **v1.0.0**（2026-06-18）—— 首发。Windows（`.bat`+`.ps1`）、macOS/Linux（`.sh`，python3 主、perl 兜底）、可选 Node 纯读取校验、中英双版 README、AI agent 自动安装指令。

参考：
- 官方上下文/长上下文文档：https://code.claude.com/docs/

---

## 作者 / Author

原创者 · Created by **Angelica-Lin**
