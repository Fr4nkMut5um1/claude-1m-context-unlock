# Changelog

本项目所有显著变更都记录在此。/ All notable changes to this project are documented here.

格式参考 [Keep a Changelog](https://keepachangelog.com/)，版本遵循 [SemVer](https://semver.org/)。

## [1.1.0] - 2026-06-18

### Added
- 细粒度安装/回滚：新增 4 个动作 —— `install-settings`（只写 settings.json）、`install-env`（只写用户环境变量 / 只追加 shell rc）、`rollback-settings`、`rollback-env`。菜单（1-7）与非交互 `-Action` / 子命令同时支持。/ Fine-grained install/rollback: added `install-settings` / `install-env` / `rollback-settings` / `rollback-env`. Available both in the menu (1-7) and as non-interactive actions/subcommands.
- 菜单条目增加白话副文案：每个动作下方多一行"普通话"解释，告诉用户这一项实际会让"桌面版 Claude" / "终端 Claude" 发生什么。/ Each menu item now has a plain-English sub-line explaining what it actually does to "desktop Claude" or "terminal Claude".
- Status 判定增加"含义"行：在原有 VERDICT 之后再说一句话讲清楚"现在这个状态意味着什么 / 接下来应该做什么"。/ Status verdicts now include a follow-up line describing what the current state means and what to do next.

### Changed
- 重启提示统一加强：无论本次只改了哪一层，都会建议你把桌面版和终端两边都重启一次，避免遗留进程读到旧值。/ Restart guidance is now unified: regardless of which layer was touched, the tool tells you to restart BOTH desktop and terminals so no stale process holds the old values.
- 副作用提示策略：只要本次动作真的写入了 `DISABLE_COMPACT=1`（任意 Install 路径），就显示 auto-compact 副作用提示；纯 Status / Rollback 不再唠叨。/ Caveat display policy: shown whenever `DISABLE_COMPACT=1` is actually written by this run (any of the three Install paths); not repeated on Status/Rollback.
- 版本号 v1.0.0 → v1.1.0。/ Version bump v1.0.0 → v1.1.0.

[1.1.0]: https://github.com/Angelica-Lin/claude-1m-context-unlock/releases/tag/v1.1.0

## [1.0.0] - 2026-06-18

### Added
- 首发。一键解除 Claude 桌面端把上下文强行截回 200k 的门禁，恢复 1M 上下文。/ Initial release: one-click bypass of the desktop gate that clamps context to 200k, restoring the 1M window.
- 机制：往 `~/.claude/settings.json` 的 `env` 块写两个键（缺一不可）`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` + `DISABLE_COMPACT=1`，触发客户端门禁之前的覆盖路径。/ Mechanism: writes two required keys to hit the client's pre-gate override path.
- Windows 安装器：`install-windows.bat`（双击入口）+ `install-windows.ps1`（PowerShell 5.1+，菜单 install/status/rollback，支持 `-DryRun` 与非交互 `-Action`）。
- macOS / Linux 安装器：`install-mac-linux.sh`（python3 改 JSON，perl 兜底；菜单 + 非交互子命令）。
- 安全改写 `settings.json`：先备份、缺则建、坏 JSON 中止、保留其它键、尊重 `CLAUDE_CONFIG_DIR`。
- 第二层兜底：两个键同时写成用户环境变量（Windows）/ 追加到 shell rc（Mac/Linux）。
- 醒目标注副作用：`DISABLE_COMPACT=1` 会关闭 auto-compact（README/AGENTS/脚本 CAVEAT 三处）。
- 中英双版 README（`README.md` / `README.en.md`）。
- `AGENTS.md`：AI agent 自动安装指令（含必说的副作用与 `/context` 验证）。
- `check-1m-context.js`：可选 Node 纯读取校验（不联网）。
- `example-settings.json`：脱敏示例。
- `assets/banner.jpg`：展示图。
- MIT License。

[1.0.0]: https://github.com/Angelica-Lin/claude-1m-context-unlock/releases/tag/v1.0.0
