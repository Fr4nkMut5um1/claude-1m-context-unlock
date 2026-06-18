# AGENTS.md — 给 AI Agent 的自动执行指令 / Instructions for AI Agents

> 🤖 **如果你是 AI agent（如 Claude Code）正在读这个工具包：本文件就是给你的。请按下面的步骤自动为本机的 Claude 桌面端解除 200k 上下文限制、恢复 1M 上下文。**
> 🤖 **If you are an AI agent (e.g. Claude Code) reading this toolkit: this file is for you. Follow the steps below to unlock the 1M context window on the local Claude desktop app (which is otherwise clamped to 200k).**

---

## 任务 / TASK

为本机 Claude 把上下文上限从被门禁截回的 200k 恢复成 1M。做法：往 `~/.claude/settings.json` 的 `env` 块写入**两个键（缺一不可）**——`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` 和 `DISABLE_COMPACT=1`——并把这两个键同时设成用户级环境变量做兜底。本工具包的安装脚本已封装好全部逻辑（备份、坏 JSON 中止、保留其它键），你只需调用它的**非交互入口**。

Restore the local Claude context limit from the gated 200k back to 1M by writing **two keys (both required)** into the `env` block of `~/.claude/settings.json` — `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` and `DISABLE_COMPACT=1` — plus the same two as user env vars for fallback. The installer scripts already encapsulate all the logic (backup, abort-on-corrupt-JSON, preserve other keys); you only need to call their **non-interactive entry point**.

---

## 步骤 / STEPS

**前提**：你已经把本工具包的文件解压到某个文件夹。先 `cd` 到那个文件夹（包含 `install-windows.ps1` / `install-mac-linux.sh` 的目录）。
**Precondition**: the toolkit files are extracted into a folder. `cd` into that folder (the one containing `install-windows.ps1` / `install-mac-linux.sh`) first.

### 第 1 步：安装 / Step 1: Install

按操作系统选一条命令运行 / Run ONE command depending on the OS:

**Windows（PowerShell 或在 bash 里调 powershell.exe）:**
```
powershell -NoProfile -ExecutionPolicy Bypass -File install-windows.ps1 -Action install
```

**macOS / Linux:**
```
chmod +x install-mac-linux.sh && ./install-mac-linux.sh install
```

这些是**非交互**命令，不需要任何键盘输入，直接执行完退出。
These are **non-interactive** — no keyboard input needed; they run and exit.

### 第 2 步：验证配置 / Step 2: Verify config (REQUIRED)

紧接着运行 status，确认两个键都写进去了 / Immediately run status to confirm BOTH keys are written:

**Windows:** `powershell -NoProfile -ExecutionPolicy Bypass -File install-windows.ps1 -Action status`
**macOS / Linux:** `./install-mac-linux.sh status`

在输出里找 **`VERDICT`** 行。看到 **`ACTIVE`**（两键齐全）即**配置正确**。若是 **`INCOMPLETE — missing XXX`**，说明少写了一个键，重跑第 1 步；若仍不行，把完整输出报告给用户并停止，不要反复重试。
Look for the **`VERDICT`** line. **`ACTIVE`** means the **config is correct**. If it says **`INCOMPLETE — missing XXX`**, a key is missing — re-run Step 1; if it still fails, report the full output to the user and stop — do not retry blindly.

> ⚠️ 注意：Status 的 `ACTIVE` 只证明**配置写对了**，不等于桌面版一定解锁了 1M。真正的判定在第 3 步交给用户做（重启后看 `/context` 分母）。
> ⚠️ Note: a Status of `ACTIVE` only proves the **config is written**, not that the desktop app actually unlocked 1M. The real confirmation is for the user in Step 3 (restart, then read the `/context` denominator).

### 第 3 步：告知用户 / Step 3: Tell the user

成功写入配置后，用几句话告诉用户以下**三点（缺一不可，尤其是副作用）**：
On success, tell the user these **three points (all required, especially the side effect)**:

1. **已写入解锁 1M 的两个键**，需**完全退出并重开桌面版**才生效（不是只关窗口；CLI 则新开终端）。/ The two keys to unlock 1M are written; **fully quit & reopen the desktop app** to take effect (not just close the window; for the CLI open a new terminal).
2. **怎么确认成功**：重开后输入 `/context`，分母显示 **`1000.0k`** = 成功，**`200.0k`** = 没生效（让用户看 README 的「失败排查」）。/ **How to confirm**: after reopening, type `/context`; a denominator of **`1000.0k`** = success, **`200.0k`** = no effect (point them to README Troubleshooting).
3. **🟥 必说的副作用**：本工具靠 `DISABLE_COMPACT=1` 绕过门禁，这会**彻底关闭 auto-compact**——上下文满了不再自动总结，需手动 `/compact` 或开新会话。这是解锁 1M 的必要代价。/ **🟥 The side effect you MUST mention**: this uses `DISABLE_COMPACT=1` to bypass the gate, which **turns OFF auto-compact** — context won't auto-summarize when full; the user must run `/compact` or start a new session. This is the necessary cost of 1M.

---

## 安全边界（你必须遵守）/ SAFETY BOUNDARIES (you must obey)

- 只调用本工具包脚本的非交互入口；**不要**自己手写 JSON 去改 `settings.json`（脚本已处理备份/坏 JSON 中止/保留其它键）。Only call the toolkit scripts; do NOT hand-edit `settings.json` yourself.
- 脚本只改 `~/.claude/settings.json` 的 `env` 块（增两个键）+ 两个用户环境变量。**不碰** token、`ANTHROPIC_BASE_URL`、`theme` 等其它键。It only touches two `env` keys + two user env vars; it leaves tokens, base URL, theme, etc. untouched.
- 尊重 `CLAUDE_CONFIG_DIR`：脚本已自动处理，你无需干预。Honors `CLAUDE_CONFIG_DIR` automatically.
- 脚本每次写盘前会自动备份 `settings.json.bak.<时间戳>`。会修改用户配置，属常规操作，可直接执行，无需额外确认。Each write auto-backs-up; this is a routine config change, safe to run.
- **务必把第 3 步的副作用告诉用户**——关闭 auto-compact 是重要后果，不能略过。Always tell the user about the auto-compact side effect in Step 3 — it's a material consequence, don't skip it.

---

## 可选附注 / OPTIONAL NOTES

- **回滚 / Rollback**：`... -Action rollback`（Windows）或 `./install-mac-linux.sh rollback`（Mac/Linux）。删除两个键并清环境变量、恢复 auto-compact，幂等。
- **纯读取校验（需 Node.js）/ Read-only check (needs Node.js)**：`node check-1m-context.js` 报告两个键是否齐全（只查配置层，不联网）。
- **若重启后仍是 200k**：见 [README.md](README.md) 的「失败排查」——常见原因是没真正重启、只设了一个键、客户端改用严格 bool 解析（把值改成 `"true"`）、或渠道本身无 1M 额度。
- 更多说明见 [README.md](README.md)（中文）/ [README.en.md](README.en.md)（English）。

---

原创者 · Created by **Angelica-Lin**
