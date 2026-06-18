# Claude 1M Context Unlock · one-click bypass of the desktop 200k context cap

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Angelica-Lin/claude-1m-context-unlock?color=blue" alt="License"></a>
  <a href="https://github.com/Angelica-Lin/claude-1m-context-unlock/releases/latest"><img src="https://img.shields.io/github/v/release/Angelica-Lin/claude-1m-context-unlock" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/deps-none-brightgreen" alt="No dependencies">
</p>

> 🌐 **Chinese version (中文): [README.md](README.md)**
>
> 🤖 **Installing with AI / Claude Code?** Drag the whole zip into Claude Code and let it read [AGENTS.md](AGENTS.md) — it will do everything automatically.

> ## ⚠️ IMPORTANT NOTICE
>
> **This toolkit is a "Vibe Coding" product (casual AI-assisted coding).** It was generated with AI help and basically tested, but is **NOT guaranteed bug-free in your environment**. Before using:
> - **Back up your `~/.claude/settings.json` first.** (The tool auto-creates `settings.json.bak.<timestamp>`, but please ALSO keep your own copy elsewhere — belt and suspenders.)
> - **Understand what it does**: it adds two keys to `settings.json` and sets two user environment variables. If that's unclear, read the docs below first or ask someone who knows.
> - **Use at your own risk.** The author/distributor accepts **no liability** for any data loss, config corruption, billing changes, or other consequences. Keep independent backups of anything important.
> - This is **NOT** an official Anthropic tool, is unaffiliated with Anthropic, and comes with **NO warranty**.

> **TL;DR** — Double-click (Windows) or run `./install-mac-linux.sh` (Mac/Linux), choose `1) Install`, **fully quit & reopen** the desktop app. Done.

---

## What is this?

A newer Claude desktop build has a gate (`longContext1mCreditsBlocked`): even if your model is supposed to support a **1M (1,000,000-token) context**, the client decides from the proxy response that "this account has no 1M credits" and **forces the context back down to 200k**. The symptom: `/context` (or the progress bar in the lower-left) shows a denominator of `200.0k` instead of `1000.0k`.

This tool uses a **higher-priority override path** inside the client to bypass that gate and restore the 1M denominator.

How it works (two layers, belt-and-suspenders):
1. Writes **two keys** (both required) into the `env` block of your `~/.claude/settings.json`:
   ```json
   "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
   "DISABLE_COMPACT": "1"
   ```
   Claude merges those into its process env at startup — **the reliable layer; works for both the desktop app and the CLI.**
2. Also sets these two keys as user-level env vars (Windows) / appends exports to your shell rc (Mac/Linux) as a second fallback layer (covers processes launched from a terminal).

**Why it works**: in the client code, when `DISABLE_COMPACT` is truthy **AND** `CLAUDE_CODE_MAX_CONTEXT_TOKENS` has a value, it `return`s that context limit **before** the gate is ever evaluated — so the code that clamps 1M to 200k never runs. Drop either key and the override path no longer triggers.

✅ No admin/root · no Node.js · no binary patching · doesn't touch your token or relay config.

---

## 🟥 Must read: the one cost is losing auto-compact

The gate is bypassed via `DISABLE_COMPACT=1`, whose side effect is to **turn OFF auto-compact entirely**:

- When the context fills up it **will NOT auto-summarize** to free space;
- You must **run `/compact` manually**, or **start a new session**.

This is the **necessary cost** of unlocking 1M, not a bug. For long-session users the 5× context (200k → 1M) is usually well worth it, but you must know auto-compaction is gone. `3) Rollback` restores auto-compact.

---

## 🚀 Quick start (lazy path — don't care how it works, just do this)

**Just want it done? Three steps:**

1. **Extract**: unzip **all files** into one folder (don't extract a single file).
2. **Run**:
   - **Windows** → double-click **`install-windows.bat`** → type `1` and Enter.
   - **macOS / Linux** → in a terminal, `cd` into that folder, run `chmod +x install-mac-linux.sh && ./install-mac-linux.sh` → type `1` and Enter.
3. **Fully quit & reopen the desktop app** (tray icon → Quit, not just close the window; for the CLI, open a new terminal). **Done.**

> Want to confirm it worked? After reopening, type `/context` in the desktop app and read the denominator: `1000.0k` = success, `200.0k` = no effect (see Troubleshooting).
>
> Even easier with AI: drag the zip into Claude Code and let it read [AGENTS.md](AGENTS.md) — it runs all of the above for you.

---

## ⚠️ One honest caveat

This tool **only writes those two keys** into your config / env so the client takes the override path. **Whether 1M is truly unlocked also depends on:**

| Precondition | Note |
|---|---|
| Your channel/account actually supports 1M | Official 1M needs the corresponding credits; a third-party relay must really forward the `context-1m` capability. This tool can't conjure 1M you don't have — it only removes the **extra** clamp the client adds. |
| This override path still exists in your desktop build | It rides on existing client logic and **a future update may change it**. If it stops working, see Troubleshooting. |

If the denominator is still `200.0k` after restarting, one of the above isn't met. The setting is harmless either way (no effect if unsupported).

---

## Install

### Windows

1. Extract **all files** from the zip into one folder.
2. Double-click **`install-windows.bat`**.
3. In the window, type `1` and Enter (Install).
4. Follow the prompt to **fully quit & reopen the desktop app**.

> No admin elevation, no execution-policy change needed — the `.bat` handles it with `-ExecutionPolicy Bypass`.

### macOS / Linux

```bash
chmod +x install-mac-linux.sh
./install-mac-linux.sh
```
Then type `1`. JSON is edited with the system `python3` (falls back to `perl` if absent).

> The desktop (GUI) app does not read shell rc files; it relies on the `settings.json` layer, which this tool writes.

---

## Verify

**Option A (most direct, the only truly reliable check):**
After restarting the desktop app, type `/context` (or look at the lower-left progress bar denominator):
- Shows **`1000.0k`** → ✅ success, 1M unlocked.
- Still **`200.0k`** → ❌ no effect, see Troubleshooting.

**Option B (config check, zero deps):**
Run the installer again, choose `2) Status`, check the **VERDICT** line: `ACTIVE` (both keys present) is what you want. Note this only confirms the **config is written correctly**, not that the desktop app definitely unlocked — the denominator in Option A is the final word.

**Option C (optional, needs Node.js):**
A standalone read-only script: `node check-1m-context.js` reports whether both keys are present. Also config-layer only.

---

## Rollback

Run the installer → choose `3) Rollback`. It removes both keys from `settings.json` and clears the matching user env vars / shell rc lines (**and restores auto-compact**). Every write is preceded by an automatic backup `settings.json.bak.<timestamp>`.

---

## Troubleshooting (still 200k after restart)

Try these, most likely first:

1. **Didn't actually restart**: you must **fully quit** the desktop process (tray → Quit), not just close the window. Env is read only at startup.
2. **Only one key set**: run `2) Status` and check the VERDICT. If it says `INCOMPLETE — missing XXX`, a key is missing — re-run `1) Install`. **Both keys are required.**
3. **Client switched to strict bool parsing**: a later update might stop accepting the literal `"1"`. Manually set both values to `"true"` in `settings.json` and restart:
   ```json
   "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
   "DISABLE_COMPACT": "true"
   ```
4. **Your channel/account simply has no 1M**: this tool only removes the client's extra clamp; it can't grant credits you don't have. Confirm whether your official quota or relay backend truly supports 1M (official needs `anthropic-beta: context-1m-2025-08-07`; some relays use `?beta=true`).
5. **The override path was removed by a newer build**: if all the above is correct and the config is confirmed written but it's still 200k, an update may have closed this path. Consider pinning a known-good desktop version and disabling auto-update.

---

## FAQ

**Q: Double-clicking the `.bat` flashes and closes / says "running scripts is disabled on this system"?**
In most cases the `-ExecutionPolicy Bypass` inside the `.bat` already gets around this. If your machine has the execution policy locked by **enterprise Group Policy**, `Bypass` won't override it. Workarounds:
- Run it directly in PowerShell:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'FULL\PATH\install-windows.ps1' -Action install }"
  ```
- Or: this tool just adds two key lines to the `env` block of `~/.claude/settings.json` — you can add them **by hand** in a text editor (see `example-settings.json`).
- If a corporate machine is fully locked down, ask your IT or use a personal machine.

**Q: No effect after running?**
Env vars only apply to **newly started** processes. For the desktop app, **fully quit and reopen** (not just close the window); for the CLI, open a **new terminal**. Then check `/context`.

**Q: With auto-compact off, what do I do when the context fills up?**
Run `/compact` manually, or start a new session. This is the normal workflow once 1M is on.

**Q: I use the CLI, not the desktop app — do I need this?**
When the CLI connects directly to the official API/channel, 1M usually works via the `[1M]` model suffix or a beta header and you likely don't need this. This tool mainly targets the **desktop app being clamped to 200k** by the gate.

---

## The two variables involved

| Variable | Effect |
|---|---|
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | Explicitly sets the context token limit. This tool writes `1000000` (= 1M). |
| `DISABLE_COMPACT` | Turns off auto-compact. **It is the trigger switch for the override path** — without it the gate is not bypassed. Truthy: `1`/`true`/`yes`/`on`; this tool writes `1`. Side effect: see "Must read" above. |

**Both keys are required** — only when both hold does the client `return` the context limit before the gate.

---

## Files

| File | Purpose |
|---|---|
| `install-windows.bat` | Windows double-click entry |
| `install-windows.ps1` | The real installer (PowerShell 5.1+) |
| `install-mac-linux.sh` | macOS / Linux installer |
| `check-1m-context.js` | Optional Node read-only check (no network) |
| `example-settings.json` | Sanitized example (don't use as-is) |
| `AGENTS.md` | Auto-execution instructions for AI agents |
| `README.en.md` | This file (English) |
| `README.md` | Chinese version |
| `CHANGELOG.md` | Version history |

---

## Safety notes

- **Never overwrites a corrupt `settings.json`** — it aborts on parse failure, leaving the original untouched.
- **Always backs up before writing**: `settings.json.bak.<timestamp>`.
- **Creates a minimal valid file if absent**: no `settings.json` → a clean one is created.
- **Preserves all your other keys**: only adds/removes those two keys; `theme`, `ANTHROPIC_BASE_URL`, token, etc. are kept as-is.
- **Honors `CLAUDE_CONFIG_DIR`**: uses it if set, otherwise the default `~/.claude`.
- **Doesn't touch token / relay config**: bypassing the gate doesn't require it.

---

## Changelog

- **v1.0.0** (2026-06-18) — Initial release. Windows (`.bat`+`.ps1`), macOS/Linux (`.sh`, python3 primary + perl fallback), optional Node read-only check, separate CN/EN READMEs, AI-agent auto-install instructions.

References:
- Official context / long-context docs: https://code.claude.com/docs/

---

## Author

Created by **Angelica-Lin**
