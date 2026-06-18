# Changelog

本项目所有显著变更都记录在此。/ All notable changes to this project are documented here.

格式参考 [Keep a Changelog](https://keepachangelog.com/)，版本遵循 [SemVer](https://semver.org/)。

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
