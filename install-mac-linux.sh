#!/usr/bin/env bash
# ============================================================================
#  Claude 1M Context Unlock  -  macOS / Linux installer
#  v1.1.0
#
#  解除 Claude 桌面端把上下文强行截回 200k 的限制, 恢复模型本应有的 1M 上下文。
#  Unlock the full 1M context window that the Claude desktop app silently caps to 200k.
#
#  机制 / Mechanism:
#    新版桌面端有门禁 (longContext1mCreditsBlocked) 会把 1M 截回 200k。客户端里有
#    一条更高优先级覆盖路径: 当 DISABLE_COMPACT 为真 且 CLAUDE_CODE_MAX_CONTEXT_TOKENS
#    有值时, 它抢在门禁判断之前 return 该值。本工具把这两个键 (缺一不可) 写进:
#      1) ~/.claude/settings.json 的 env 块 (启动时合并进 process.env, 桌面版/CLI 都生效)
#      2) shell rc 追加 export 兜底 (仅覆盖终端启动的进程; 桌面版靠 settings.json 那层)
#
#    v1.1.0 新增: 细粒度选项, 你可以只写 settings.json 或只追加 shell rc.
#    v1.1.0 adds fine-grained options: settings-only or shell-rc-only installs.
#
#  副作用 / SIDE EFFECT (重要 / important):
#    DISABLE_COMPACT=1 会彻底关闭 auto-compact: 上下文满了不再自动总结, 需手动
#    /compact 或开新会话。这是开启 1M 的必要代价。
#    DISABLE_COMPACT=1 turns OFF auto-compact: context won't auto-summarize when full.
#
#  用法 / Usage:
#    chmod +x install-mac-linux.sh
#    ./install-mac-linux.sh
#    非交互 / non-interactive (for AI agents):
#      ./install-mac-linux.sh install              (两层都写 / both layers)
#      ./install-mac-linux.sh install-settings     (只写 settings.json)
#      ./install-mac-linux.sh install-env          (只追加 shell rc)
#      ./install-mac-linux.sh status
#      ./install-mac-linux.sh rollback             (两层都撤)
#      ./install-mac-linux.sh rollback-settings
#      ./install-mac-linux.sh rollback-env
#    测试 / testing:  CLAUDE_CONFIG_DIR=$(mktemp -d) ./install-mac-linux.sh
#
#  不需要 root, 不需要 Node.js。改 JSON 用 python3 (perl 兜底)。
#  No root, no Node.js. Edits JSON with python3 (perl fallback).
# ============================================================================

set -u

VERSION="v1.1.0"
VAR_CTX="CLAUDE_CODE_MAX_CONTEXT_TOKENS"
VAR_NOCMP="DISABLE_COMPACT"
VAL_CTX="1000000"
VAL_NOCMP="1"
MARKER="# claude-1m-context-unlock"

# --- 配置路径 (尊重 CLAUDE_CONFIG_DIR) ---
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    CONFIG_DIR="$CLAUDE_CONFIG_DIR"
else
    CONFIG_DIR="$HOME/.claude"
fi
SETTINGS="$CONFIG_DIR/settings.json"

# --- 检测 JSON 工具 / detect JSON tool ---
JSON_TOOL=""
detect_json_tool() {
    if command -v python3 >/dev/null 2>&1; then
        JSON_TOOL="python3"
    elif command -v perl >/dev/null 2>&1; then
        JSON_TOOL="perl"
    else
        echo "[ERROR] 未找到 python3 或 perl, 无法安全编辑 JSON。" >&2
        echo "        Neither python3 nor perl found; cannot safely edit JSON." >&2
        echo "        macOS: 运行 xcode-select --install 安装 python3 后重试。" >&2
        exit 1
    fi
}

# --- 用 python3 设置/删除 env 键 (原子写, 坏 JSON 中止) ---
py_set() {  # path key value
    python3 - "$1" "$2" "$3" <<'PYEOF'
import sys, json, os
path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
except FileNotFoundError:
    obj = {}
except json.JSONDecodeError as e:
    sys.stderr.write("INVALID_JSON: %s\n" % e); sys.exit(2)
if not isinstance(obj, dict):
    sys.stderr.write("NOT_OBJECT\n"); sys.exit(3)
env = obj.get('env')
if not isinstance(env, dict):
    env = {}; obj['env'] = env
env[key] = value
tmp = path + '.tmp'
with open(tmp, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(obj, f, indent=2, ensure_ascii=False); f.write('\n')
os.replace(tmp, path)
PYEOF
}
py_del() {  # path key
    python3 - "$1" "$2" <<'PYEOF'
import sys, json, os
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
except FileNotFoundError:
    sys.exit(0)
except json.JSONDecodeError as e:
    sys.stderr.write("INVALID_JSON: %s\n" % e); sys.exit(2)
if isinstance(obj, dict) and isinstance(obj.get('env'), dict):
    obj['env'].pop(key, None)
tmp = path + '.tmp'
with open(tmp, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(obj, f, indent=2, ensure_ascii=False); f.write('\n')
os.replace(tmp, path)
PYEOF
}
py_get() {  # path key  -> prints value or nothing
    python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import sys, json
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
    v = obj.get('env', {}).get(key)
    if v is not None: print(v)
except Exception:
    pass
PYEOF
}

# --- perl 兜底 (受限, 会警告) / perl fallback (limited, warns) ---
perl_set() {  # path key value
    echo "[WARN] 未装 python3, 使用 perl 兜底 (较不稳)。强烈建议装 python3 后重跑。" >&2
    echo "       python3 not found; using perl fallback. Install python3 and re-run." >&2
    local path="$1" key="$2" val="$3" tmp
    tmp="${path}.tmp.$$"
    [ -s "$path" ] || echo '{}' > "$path"
    KEY="$key" VAL="$val" perl -0777 -pe '
        my $key=$ENV{KEY}; my $val=$ENV{VAL};
        if (/"env"\s*:\s*\{/s) {
            if (/"\Q$key\E"\s*:/s) { s/("\Q$key\E"\s*:\s*)"[^"]*"/$1"$val"/s; }
            else { s/("env"\s*:\s*\{)/$1\n    "$key": "$val",/s; }
        } else {
            s/\}\s*$/,\n  "env": {\n    "$key": "$val"\n  }\n}\n/s;
        }
    ' "$path" > "$tmp" && mv "$tmp" "$path" || { rm -f "$tmp"; echo "[ERROR] perl 编辑失败, 原文件未动。" >&2; exit 1; }
}
perl_del() {  # path key
    local path="$1" key="$2" tmp
    [ -f "$path" ] || return 0
    tmp="${path}.tmp.$$"
    KEY="$key" perl -0777 -pe '
        my $key=$ENV{KEY};
        s/\n?\s*"\Q$key\E"\s*:\s*"[^"]*"\s*,?//s;
        s/,(\s*\})/$1/s;
    ' "$path" > "$tmp" && mv "$tmp" "$path" || { rm -f "$tmp"; echo "[ERROR] perl 删除失败。" >&2; exit 1; }
}

# --- 校验 JSON / validate ---
validate_json() {  # path  -> exit 1 if invalid
    [ -f "$SETTINGS" ] || return 0
    if [ ! -s "$SETTINGS" ]; then
        echo "[ERROR] $SETTINGS 存在但为空, 已中止。" >&2
        echo "        File exists but is empty. Aborting." >&2
        exit 1
    fi
    if [ "$JSON_TOOL" = "python3" ]; then
        if ! python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$SETTINGS" 2>/dev/null; then
            echo "[ERROR] $SETTINGS 不是合法 JSON, 已中止 (绝不覆盖)。" >&2
            echo "        Not valid JSON. Aborting (never overwrites a corrupt file)." >&2
            exit 1
        fi
    fi
}

# --- 备份 / backup ---
backup_settings() {
    [ -f "$SETTINGS" ] || return 0
    local bak="${SETTINGS}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$SETTINGS" "$bak"
    echo "[BAK] 已备份 / backed up -> $bak"
}

ensure_file() {
    mkdir -p "$CONFIG_DIR"
    [ -f "$SETTINGS" ] || { printf '{}' > "$SETTINGS"; echo "[NEW] 已创建 / created: $SETTINGS"; }
}

set_key()  { if [ "$JSON_TOOL" = "python3" ]; then py_set "$SETTINGS" "$1" "$2" || { echo "[ERROR] JSON 编辑失败 (可能坏 JSON), 已中止。" >&2; exit 1; }; else perl_set "$SETTINGS" "$1" "$2"; fi; }
del_key()  { if [ "$JSON_TOOL" = "python3" ]; then py_del "$SETTINGS" "$1" || { echo "[ERROR] JSON 删除失败, 已中止。" >&2; exit 1; }; else perl_del "$SETTINGS" "$1"; fi; }
get_key()  { if [ "$JSON_TOOL" = "python3" ]; then py_get "$SETTINGS" "$1"; fi; }

# --- shell rc 追加/清理 / append/remove exports in shell rc ---
rc_files() {
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        [ -f "$f" ] && echo "$f"
    done
}
append_rc() {
    local touched=0
    while IFS= read -r rc; do
        [ -z "$rc" ] && continue
        if grep -q "$MARKER" "$rc" 2>/dev/null; then
            echo "[--] 已存在 / already in: $rc"
        else
            printf '\n%s\n%s\n%s\n' "$MARKER" "export $VAR_CTX=\"$VAL_CTX\"" "export $VAR_NOCMP=\"$VAL_NOCMP\"" >> "$rc"
            echo "[OK] 已追加 / appended to: $rc"
            touched=1
        fi
    done <<EOF
$(rc_files)
EOF
    if [ "$touched" = "0" ] && [ -z "$(rc_files)" ]; then
        # 一个 rc 都没有: 创建 ~/.profile
        printf '%s\n%s\n%s\n' "$MARKER" "export $VAR_CTX=\"$VAL_CTX\"" "export $VAR_NOCMP=\"$VAL_NOCMP\"" >> "$HOME/.profile"
        echo "[OK] 已创建并写入 / created: $HOME/.profile"
    fi
}
remove_rc() {
    local touched=0
    while IFS= read -r rc; do
        [ -z "$rc" ] && continue
        if grep -q "$MARKER" "$rc" 2>/dev/null; then
            local tmp="${rc}.tmp.$$"
            grep -v "$MARKER" "$rc" | grep -v "export $VAR_CTX=" | grep -v "export $VAR_NOCMP=" > "$tmp" && mv "$tmp" "$rc"
            echo "[OK] 已从 $rc 清除。"
            touched=1
        fi
    done <<EOF
$(rc_files)
EOF
    if [ "$touched" = "0" ]; then
        echo "[--] 没有在任何 shell rc 里找到本工具的 marker, 无需处理。"
    fi
}

show_next_steps() {
    echo ""
    echo "下一步 / NEXT STEPS:"
    echo "  即便本次只改了一层, 也建议两边都重启一次, 避免遗留进程读到旧值。"
    echo "  Even if you only touched one layer, restart BOTH to avoid stale processes reading old values."
    echo "  桌面版:  完全退出 Claude 桌面版再重开 (它不读 shell rc, 靠 settings.json)。"
    echo "  Desktop: Fully quit & reopen the app (it reads settings.json, not shell rc)."
    echo "  CLI:     source ~/.zshrc (或 ~/.bashrc), 或新开一个终端 (建议把开着的终端都关一遍)。"
    echo "           source your rc file, or open a NEW terminal (close existing ones too if possible)."
    echo "  验证 / verify: 重开后看 /context 或左下角分母 — 1000.0k = 成功, 200.0k = 失败。"
}
show_caveat() {
    echo ""
    echo "重要副作用 / IMPORTANT SIDE EFFECT:"
    echo "  本工具用 DISABLE_COMPACT=1 绕过门禁, 这会彻底关闭 auto-compact:"
    echo "  上下文满了不再自动总结, 需手动 /compact 或开新会话。这是解锁 1M 的代价。"
    echo "  This uses DISABLE_COMPACT=1 to bypass the gate, turning OFF auto-compact:"
    echo "  context won't auto-summarize when full; run /compact or start a new session."
    echo ""
    echo "  另外: 能否解锁取决于你的桌面版版本/渠道是否真支持 1M。若分母仍是 200k,"
    echo "  见 README 的「失败排查」(可先把两个值都改成 \"true\" 再试)。"
    echo "  Also: success depends on your desktop build/channel supporting 1M; if it stays"
    echo "  200k, see README troubleshooting (try the literal \"true\" first)."
}
show_rollback_tail() {
    echo ""
    echo "回滚完成。source rc 或新开终端 / 完全退出并重开桌面版 后生效。"
    echo "Rollback done. source your rc / relaunch terminal / fully quit+reopen the desktop app."
    echo "提示 / NOTE: 回滚同时关闭了 DISABLE_COMPACT, auto-compact 会恢复 (仅对被回滚的那一层)。"
}

# --- 判断真值 (用于 DISABLE_COMPACT) / truthy check ---
is_truthy() {  # value
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================ 动作 / ACTIONS ============================

# 共用: 写两键到 settings.json (备份在外面做)
write_settings_keys() {
    detect_json_tool
    ensure_file
    validate_json
    set_key "$VAR_CTX"   "$VAL_CTX"
    set_key "$VAR_NOCMP" "$VAL_NOCMP"
    echo "[OK] settings.json 已更新 / updated:"
    echo "       $VAR_CTX = $VAL_CTX"
    echo "       $VAR_NOCMP = $VAL_NOCMP"
}
# 共用: 从 settings.json 删两键
remove_settings_keys() {
    detect_json_tool
    if [ -f "$SETTINGS" ]; then
        validate_json
        local any=0
        for k in "$VAR_CTX" "$VAR_NOCMP"; do
            if [ -n "$(get_key "$k")" ]; then any=1; fi
        done
        if [ "$any" = "1" ]; then
            del_key "$VAR_CTX"
            del_key "$VAR_NOCMP"
            echo "[OK] 已从 settings.json 删除 $VAR_CTX 与 $VAR_NOCMP。"
        else
            echo "[--] settings.json 里本就没有这两个键。"
        fi
    else
        echo "[--] settings.json 不存在。"
    fi
}

do_install() {
    echo ""
    echo ">>> 解锁 1M 上下文 (两层都写) / Unlocking 1M (both layers) ..."
    backup_settings
    write_settings_keys
    append_rc
    show_next_steps
    show_caveat
}
do_install_settings() {
    echo ""
    echo ">>> 仅写 settings.json / Writing settings.json only ..."
    backup_settings
    write_settings_keys
    echo "[--] 跳过 shell rc (本次只改 settings.json)。"
    echo "     shell rc skipped (settings.json only this run)."
    show_next_steps
    show_caveat
}
do_install_env() {
    echo ""
    echo ">>> 仅追加 shell rc 的 export / Appending shell rc exports only ..."
    echo "[--] 跳过 settings.json (本次只改 shell rc)。"
    echo "     settings.json skipped (shell rc only this run)."
    append_rc
    show_next_steps
    show_caveat
}

do_rollback() {
    echo ""
    echo ">>> 回滚 (两层都撤) / Rolling back (both layers) ..."
    if [ -f "$SETTINGS" ]; then backup_settings; fi
    remove_settings_keys
    remove_rc
    show_rollback_tail
}
do_rollback_settings() {
    echo ""
    echo ">>> 回滚 settings.json / Rolling back settings.json ..."
    if [ -f "$SETTINGS" ]; then backup_settings; fi
    remove_settings_keys
    echo "[--] 跳过 shell rc (本次只回滚 settings.json)。"
    echo "     shell rc left as-is (settings.json only this run)."
    show_rollback_tail
}
do_rollback_env() {
    echo ""
    echo ">>> 回滚 shell rc 的 export / Rolling back shell rc exports ..."
    echo "[--] 跳过 settings.json (本次只回滚 shell rc)。"
    echo "     settings.json left as-is (shell rc only this run)."
    remove_rc
    show_rollback_tail
}

do_status() {
    detect_json_tool
    echo ""
    echo "--- settings.json ($SETTINGS) ---"
    local sCtx sNoCmp
    if [ -f "$SETTINGS" ]; then
        sCtx="$(get_key "$VAR_CTX")"; sNoCmp="$(get_key "$VAR_NOCMP")"
        echo "  $VAR_CTX = ${sCtx:-(未设/not set)}"
        echo "  $VAR_NOCMP = ${sNoCmp:-(未设/not set)}"
    else
        echo "  (文件不存在 / file does not exist)"
        sCtx=""; sNoCmp=""
    fi
    echo ""
    echo "--- shell rc 是否含本工具 marker / shell rc has marker? ---"
    local rc_hit=0
    while IFS= read -r rc; do
        [ -z "$rc" ] && continue
        if grep -q "$MARKER" "$rc" 2>/dev/null; then
            echo "  [Y] $rc"
            rc_hit=1
        fi
    done <<EOF
$(rc_files)
EOF
    [ "$rc_hit" = "0" ] && echo "  (没找到 / not found in any rc)"
    echo ""
    echo "--- 当前 shell 环境 / current shell env ---"
    echo "  $VAR_CTX = ${CLAUDE_CODE_MAX_CONTEXT_TOKENS:-(未设/not set)}"
    echo "  $VAR_NOCMP = ${DISABLE_COMPACT:-(未设/not set)}"
    echo "  (注: 这反映的是当前终端; 桌面版以 settings.json 为准)"
    echo ""
    local ctx_ok=0 nocmp_ok=0
    [ -n "$sCtx" ] && [ "$sCtx" != "0" ] && ctx_ok=1
    is_truthy "$sNoCmp" && nocmp_ok=1
    if [ "$ctx_ok" = "1" ] && [ "$nocmp_ok" = "1" ]; then
        echo "判定 / VERDICT: settings.json 两键齐全, 1M 已解锁 / ACTIVE。"
        echo "    含义: 桌面版应已解锁; CLI 也会读 settings.json, 通常照样生效。"
        echo "    Meaning: desktop should be unlocked; CLI reads settings.json too, so it likely works too."
    elif [ "$ctx_ok" = "1" ] || [ "$nocmp_ok" = "1" ]; then
        if [ "$ctx_ok" = "0" ]; then miss="$VAR_CTX"; else miss="$VAR_NOCMP"; fi
        echo "判定 / VERDICT: settings.json 缺一键 ($miss), 不会生效 (两键缺一不可) / INCOMPLETE — missing $miss。"
        echo "    含义: 缺一个键, 覆盖路径不会触发, 桌面版仍会被截回 200k。重跑 Install 即可。"
        echo "    Meaning: missing one key; the override path won't trigger; desktop will stay at 200k. Re-run Install."
    else
        if [ "$rc_hit" = "1" ]; then
            echo "判定 / VERDICT: settings.json 未启用, 但 shell rc 已写 / PARTIAL (shell rc only)。"
            echo "    含义: 从终端启动的 Claude 应解锁; 桌面版不读 shell rc, 仍会是 200k。建议补 settings.json。"
            echo "    Meaning: terminal-launched Claude should be unlocked; the desktop app doesn't read shell rc, so it will stay at 200k. Add settings.json too."
        else
            echo "判定 / VERDICT: 未启用 / NOT enabled。"
            echo "    含义: 两层都没设, 1M 没有解锁, /context 分母会是 200.0k。运行 Install 即可。"
            echo "    Meaning: neither layer is set; 1M is not unlocked; /context will show 200.0k. Run Install to fix."
        fi
    fi
    echo "确认生效: 重启桌面版后看 /context 或左下角分母 — 1000.0k = 成功, 200.0k = 未生效。"
}

# 非交互模式 / Non-interactive (AI agent) dispatch
if [ $# -gt 0 ]; then
    case "$1" in
        install)            do_install            ;;
        install-settings)   do_install_settings   ;;
        install-env)        do_install_env        ;;
        status)             do_status             ;;
        rollback)           do_rollback           ;;
        rollback-settings)  do_rollback_settings  ;;
        rollback-env)       do_rollback_env       ;;
        *) echo "[ERROR] 未知动作 / Unknown action: $1" >&2
           echo "Usage: $0 [install|install-settings|install-env|status|rollback|rollback-settings|rollback-env]" >&2
           exit 1 ;;
    esac
    exit 0
fi

# ============================ 菜单 / MENU ============================
menu() {
    echo ""
    echo "=================================================="
    echo " Claude 1M Context Unlock  $VERSION"
    echo "=================================================="
    echo " 配置文件 / config: $SETTINGS"
    echo ""
    echo "  1) Install (both)               两层都写 (推荐)"
    echo "     -> 一键搞定, 桌面版和终端两边都解锁 1M"
    echo "     -> One-click: unlock 1M for both desktop and terminal."
    echo ""
    echo "  2) Install settings.json only   只写 settings.json"
    echo "     -> 只让桌面版的 Claude 解锁 1M, 不动你的 shell rc"
    echo "     -> Unlock the desktop Claude only; leave your shell rc alone."
    echo ""
    echo "  3) Install shell rc only        只追加 shell rc 的 export"
    echo "     -> 只让从终端启动的 Claude 解锁 1M, 不改配置文件"
    echo "     -> Unlock terminal-launched Claude only; don't touch the config file."
    echo ""
    echo "  4) Status                       查看当前状态"
    echo "     -> 看现在是不是已经解锁, 没解锁缺哪个"
    echo "     -> Check whether it's unlocked now and which key (if any) is missing."
    echo ""
    echo "  5) Rollback (both)              两层都回滚 (回到 200k)"
    echo "     -> 一键还原, 把所有改动撤掉, 回到默认 200k"
    echo "     -> One-click revert: undo everything, back to the default 200k."
    echo ""
    echo "  6) Rollback settings.json only  只回滚 settings.json"
    echo "     -> 只撤掉对桌面版的解锁, shell rc 保留"
    echo "     -> Undo the desktop unlock only; keep shell rc as it is."
    echo ""
    echo "  7) Rollback shell rc only       只回滚 shell rc"
    echo "     -> 只撤掉对终端的解锁, 配置文件保留"
    echo "     -> Undo the terminal unlock only; keep the config file as it is."
    echo ""
    echo "  q) Quit                         退出"
    echo ""
}

while true; do
    menu
    printf "请选择 / Choose: "
    read -r choice || break
    case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
        1) do_install ;;
        2) do_install_settings ;;
        3) do_install_env ;;
        4) do_status ;;
        5) do_rollback ;;
        6) do_rollback_settings ;;
        7) do_rollback_env ;;
        q) echo "再见 / Bye."; break ;;
        *) echo "无效选择 / invalid choice: $choice" ;;
    esac
done
