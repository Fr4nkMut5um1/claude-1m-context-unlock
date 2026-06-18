<#
================================================================================
 Claude 1M Context Unlock  -  Windows installer (PowerShell 5.1+)
 v1.1.1

 解除 Claude 桌面端把上下文强行截回 200k 的限制, 恢复模型本应有的 1M 上下文。
 Unlock the full 1M context window that the Claude desktop app silently caps to 200k.

 机制 / Mechanism:
   新版桌面端有个门禁 (longContext1mCreditsBlocked), 即便模型名带 [1M] 也会把
   1M 截回 200k。但客户端里有一条更高优先级的覆盖路径: 当
     DISABLE_COMPACT 为真  且  CLAUDE_CODE_MAX_CONTEXT_TOKENS 有值
   时, 它抢在门禁判断之前就 return 这个值, 门禁那行根本走不到。
   本工具就是把这两个键 (缺一不可) 写进:
     1) ~/.claude/settings.json 的 env 块 (启动时合并进 process.env, 桌面版/CLI 都生效)
     2) 用户级环境变量 (兜底, 覆盖从终端启动的进程)

   v1.1.0 新增: 细粒度选项, 你可以选择只写 settings.json (只解锁桌面版), 或只写
   用户环境变量 (只解锁终端). 仍推荐两层都写, 互为兜底.

   A newer desktop build gates 1M behind longContext1mCreditsBlocked and forces it
   back to 200k. There is a higher-priority override path: when DISABLE_COMPACT is
   truthy AND CLAUDE_CODE_MAX_CONTEXT_TOKENS has a value, the client returns that
   value before the gate is ever reached. This tool writes BOTH keys (both required)
   into settings.json's env block plus user env vars.

   v1.1.0 adds fine-grained options: settings-only (desktop only) or env-only
   (terminal only). Both layers (the default) is still recommended.

 副作用 / SIDE EFFECT (重要 / important):
   DISABLE_COMPACT=1 会彻底关闭 auto-compact。上下文满了不再自动总结,
   需要你手动 /compact 或开新会话。这是开启 1M 的必要代价。
   DISABLE_COMPACT=1 turns OFF auto-compact entirely: when the context fills up it
   will NOT auto-summarize; you must run /compact yourself or start a new session.

 用法 / Usage:
   双击 install-windows.bat            (推荐 / recommended)
   或 / or:  powershell -ExecutionPolicy Bypass -File install-windows.ps1
   非交互 / non-interactive (for AI agents):
     powershell -NoProfile -ExecutionPolicy Bypass -File install-windows.ps1 -Action install
     (Action 可选 / one of:
        install              两层都写 / both layers (recommended)
        install-settings     只写 settings.json / settings.json only
        install-env          只写用户环境变量 / user env vars only
        status               查看状态 / show state
        rollback             两层都回滚 / rollback both
        rollback-settings    只回滚 settings.json / rollback settings.json only
        rollback-env         只回滚用户环境变量 / rollback user env vars only
     )
   测试 / testing:  ... install-windows.ps1 -DryRun   (只打印, 不写盘)

 不需要管理员权限, 不需要 Node.js。
 No admin rights, no Node.js required.
================================================================================
#>

param(
    [switch]$DryRun,
    [ValidateSet("install","install-settings","install-env","status","rollback","rollback-settings","rollback-env","")]
    [string]$Action = ""
)

$VERSION   = "v1.1.1"
$VAR_CTX   = "CLAUDE_CODE_MAX_CONTEXT_TOKENS"
$VAR_NOCMP = "DISABLE_COMPACT"
$VAL_CTX   = "1000000"
$VAL_NOCMP = "1"

# --- 配置路径 (尊重 CLAUDE_CONFIG_DIR) / Config path (honors CLAUDE_CONFIG_DIR) ---
function Get-ConfigDir {
    if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR }
    return (Join-Path $env:USERPROFILE ".claude")
}
$ConfigDir    = Get-ConfigDir
$SettingsPath = Join-Path $ConfigDir "settings.json"

# --- UTF-8 无 BOM 写盘 / Write UTF-8 without BOM ---
function Write-JsonFile {
    param([string]$Path, [string]$Content)
    if ($DryRun) {
        Write-Host "[DRY-RUN] 将写入 / would write: $Path" -ForegroundColor Magenta
        return
    }
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# --- 读取并解析 settings.json; 坏 JSON 则中止 / Read+parse; abort on bad JSON ---
# 返回 PSCustomObject; 文件不存在返回 $null
function Read-Settings {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content -Raw -Encoding UTF8 -Path $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-Host "[ERROR] $Path 存在但为空/全空白。已中止以免破坏。" -ForegroundColor Red
        Write-Host "        File exists but is empty/whitespace. Aborting to avoid damage." -ForegroundColor Red
        Write-Host "        请手动删除或修复该文件后重试。" -ForegroundColor Yellow
        exit 1
    }
    try {
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-Host "[ERROR] $Path 不是合法 JSON, 已中止 (绝不覆盖)。" -ForegroundColor Red
        Write-Host "        Not valid JSON. Aborting (never overwrites a corrupt file)." -ForegroundColor Red
        Write-Host "        细节 / detail: $_" -ForegroundColor DarkGray
        exit 1
    }
}

# --- 备份 / Backup ---
function Backup-Settings {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = "$Path.bak.$ts"
    if ($DryRun) {
        Write-Host "[DRY-RUN] 将备份 / would back up -> $bak" -ForegroundColor Magenta
        return
    }
    Copy-Item -Path $Path -Destination $bak -Force
    Write-Host "[BAK] 已备份 / backed up -> $bak" -ForegroundColor DarkGray
}

# --- 工具: env 子对象存在性与读写 / helpers for the env sub-object ---
function Has-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $false }
    return [bool]($Obj.PSObject.Properties.Name -contains $Name)
}
function Ensure-EnvBlock {
    param($Obj)
    if (-not (Has-Prop $Obj "env")) {
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "env" -Value ([PSCustomObject]@{})
    }
    return $Obj.env
}

# --- 确保 settings.json 与目录存在 (返回解析后的对象) ---
function Ensure-SettingsObject {
    if (-not (Test-Path $ConfigDir)) {
        if ($DryRun) { Write-Host "[DRY-RUN] 将创建目录 / would create dir: $ConfigDir" -ForegroundColor Magenta }
        else {
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
            Write-Host "[NEW] 已创建目录 / created dir: $ConfigDir" -ForegroundColor DarkGray
        }
    }
    if (-not (Test-Path $SettingsPath)) {
        Write-JsonFile -Path $SettingsPath -Content "{}"
        Write-Host "[NEW] 已创建 / created: $SettingsPath" -ForegroundColor DarkGray
        if ($DryRun) { return ([PSCustomObject]@{}) }
    }
    $obj = Read-Settings $SettingsPath
    if ($null -eq $obj) { $obj = [PSCustomObject]@{} }
    return $obj
}

# --- 设/删 用户环境变量 / set/remove User env var ---
function Set-UserEnv {
    param([string]$Name, $Value)   # $Value=$null 表示删除
    if ($DryRun) {
        if ($null -eq $Value) { Write-Host "[DRY-RUN] 将删除用户环境变量 / would remove User env: $Name" -ForegroundColor Magenta }
        else { Write-Host "[DRY-RUN] 将设用户环境变量 / would set User env: $Name=$Value" -ForegroundColor Magenta }
        return
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
}
function Get-UserEnv {
    param([string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, "User")
}

# ============================ 原子操作 / ATOMIC HELPERS ============================

# 写两个键进 settings.json (备份在外面做; 不在这里做)
function Write-SettingsKeys {
    $obj = Ensure-SettingsObject
    $env = Ensure-EnvBlock $obj
    Add-Member -InputObject $env -MemberType NoteProperty -Name $VAR_CTX   -Value $VAL_CTX   -Force
    Add-Member -InputObject $env -MemberType NoteProperty -Name $VAR_NOCMP -Value $VAL_NOCMP -Force
    $json = $obj | ConvertTo-Json -Depth 10
    Write-JsonFile -Path $SettingsPath -Content $json
    Write-Host "[OK] settings.json 已更新 / updated:" -ForegroundColor Green
    Write-Host "       $VAR_CTX = $VAL_CTX" -ForegroundColor Green
    Write-Host "       $VAR_NOCMP = $VAL_NOCMP" -ForegroundColor Green
}

# 删 settings.json 里的两个键; 返回 $true 表示真的删了点东西
function Remove-SettingsKeys {
    if (-not (Test-Path $SettingsPath)) {
        Write-Host "[--] settings.json 不存在, 无需处理。" -ForegroundColor DarkGray
        return $false
    }
    $obj = Read-Settings $SettingsPath
    if (-not (Has-Prop $obj "env")) {
        Write-Host "[--] settings.json 无 env 块, 无需处理。" -ForegroundColor DarkGray
        return $false
    }
    $removed = $false
    foreach ($k in @($VAR_CTX, $VAR_NOCMP)) {
        if (Has-Prop $obj.env $k) {
            $obj.env.PSObject.Properties.Remove($k)
            Write-Host "[OK] 已从 settings.json 删除 $k。" -ForegroundColor Green
            $removed = $true
        }
    }
    if ($removed) {
        $json = $obj | ConvertTo-Json -Depth 10
        Write-JsonFile -Path $SettingsPath -Content $json
    } else {
        Write-Host "[--] settings.json 里本就没有这两个键。" -ForegroundColor DarkGray
    }
    return $removed
}

function Write-UserEnvKeys {
    Set-UserEnv $VAR_CTX   $VAL_CTX
    Set-UserEnv $VAR_NOCMP $VAL_NOCMP
    Write-Host "[OK] 用户环境变量已设 / User env vars set ($VAR_CTX, $VAR_NOCMP)。" -ForegroundColor Green
}

function Remove-UserEnvKeys {
    foreach ($k in @($VAR_CTX, $VAR_NOCMP)) {
        if (Get-UserEnv $k) {
            Set-UserEnv $k $null
            Write-Host "[OK] 已删除用户环境变量 $k。" -ForegroundColor Green
        } else {
            Write-Host "[--] 用户环境变量 $k 本就没设。" -ForegroundColor DarkGray
        }
    }
}

# ============================ 动作 / ACTIONS ============================

function Action-Install {
    Write-Host ""
    Write-Host ">>> 解锁 1M 上下文 (两层都写) / Unlocking 1M context (both layers) ..." -ForegroundColor Cyan
    Backup-Settings $SettingsPath
    Write-SettingsKeys
    Write-UserEnvKeys
    Show-NextSteps
    Show-Caveat
}

function Action-InstallSettings {
    Write-Host ""
    Write-Host ">>> 仅写 settings.json / Writing settings.json only ..." -ForegroundColor Cyan
    Backup-Settings $SettingsPath
    Write-SettingsKeys
    Write-Host "[--] 跳过用户环境变量 (本次只改 settings.json)。" -ForegroundColor DarkGray
    Write-Host "     User env vars skipped (settings.json only this run)." -ForegroundColor DarkGray
    Show-NextSteps
    Show-Caveat
}

function Action-InstallEnv {
    Write-Host ""
    Write-Host ">>> 仅写用户环境变量 / Writing user env vars only ..." -ForegroundColor Cyan
    Write-Host "[--] 跳过 settings.json (本次只改用户环境变量)。" -ForegroundColor DarkGray
    Write-Host "     settings.json skipped (user env vars only this run)." -ForegroundColor DarkGray
    Write-UserEnvKeys
    Show-NextSteps
    Show-Caveat
}

function Action-Rollback {
    Write-Host ""
    Write-Host ">>> 回滚 (两层都撤) / Rolling back (both layers) ..." -ForegroundColor Cyan
    if (Test-Path $SettingsPath) { Backup-Settings $SettingsPath }
    [void](Remove-SettingsKeys)
    Remove-UserEnvKeys
    Show-RollbackTail
}

function Action-RollbackSettings {
    Write-Host ""
    Write-Host ">>> 回滚 settings.json / Rolling back settings.json ..." -ForegroundColor Cyan
    if (Test-Path $SettingsPath) { Backup-Settings $SettingsPath }
    [void](Remove-SettingsKeys)
    Write-Host "[--] 跳过用户环境变量 (本次只回滚 settings.json)。" -ForegroundColor DarkGray
    Write-Host "     User env vars left as-is (settings.json only this run)." -ForegroundColor DarkGray
    Show-RollbackTail
}

function Action-RollbackEnv {
    Write-Host ""
    Write-Host ">>> 回滚用户环境变量 / Rolling back user env vars ..." -ForegroundColor Cyan
    Write-Host "[--] 跳过 settings.json (本次只回滚用户环境变量)。" -ForegroundColor DarkGray
    Write-Host "     settings.json left as-is (user env vars only this run)." -ForegroundColor DarkGray
    Remove-UserEnvKeys
    Show-RollbackTail
}

function Action-Status {
    Write-Host ""
    Write-Host "--- settings.json ($SettingsPath) ---" -ForegroundColor Cyan
    $sCtx = $false; $sNoCmp = $false
    if (Test-Path $SettingsPath) {
        $obj = Read-Settings $SettingsPath
        if (Has-Prop $obj "env") {
            $e = $obj.env
            $vCtx   = if (Has-Prop $e $VAR_CTX)   { "'" + $e.$VAR_CTX   + "'" } else { "(未设/not set)" }
            $vNoCmp = if (Has-Prop $e $VAR_NOCMP) { "'" + $e.$VAR_NOCMP + "'" } else { "(未设/not set)" }
            Write-Host "  $VAR_CTX = $vCtx"
            Write-Host "  $VAR_NOCMP = $vNoCmp"
            $sCtx   = (Has-Prop $e $VAR_CTX)   -and ([string]$e.$VAR_CTX   -ne "") -and ([string]$e.$VAR_CTX -ne "0")
            $sNoCmp = (Has-Prop $e $VAR_NOCMP) -and (@("1","true","yes","on") -contains ([string]$e.$VAR_NOCMP).ToLower())
        } else {
            Write-Host "  (无 env 块 / no env block)"
        }
    } else {
        Write-Host "  (文件不存在 / file does not exist)"
    }

    Write-Host ""
    Write-Host "--- 用户环境变量 / User environment variables ---" -ForegroundColor Cyan
    $ueCtx   = Get-UserEnv $VAR_CTX
    $ueNoCmp = Get-UserEnv $VAR_NOCMP
    $dCtx    = if ($ueCtx)   { "'" + $ueCtx   + "'" } else { "(未设/not set)" }
    $dNoCmp  = if ($ueNoCmp) { "'" + $ueNoCmp + "'" } else { "(未设/not set)" }
    Write-Host "  $VAR_CTX = $dCtx"
    Write-Host "  $VAR_NOCMP = $dNoCmp"
    $eCtx   = ($ueCtx)   -and ($ueCtx   -ne "0")
    $eNoCmp = ($ueNoCmp) -and (@("1","true","yes","on") -contains ([string]$ueNoCmp).ToLower())

    $settingsOk = $sCtx -and $sNoCmp
    $envOk      = $eCtx -and $eNoCmp
    $settingsPartial = ($sCtx -or $sNoCmp) -and (-not $settingsOk)
    $envPartial      = ($eCtx -or $eNoCmp) -and (-not $envOk)

    Write-Host ""
    # 判定 + 后果说明 (你回家看 README 的"普通话"版)
    if ($settingsOk -and $envOk) {
        Write-Host "判定 / VERDICT: 1M 已解锁 (两层都齐全) / ACTIVE (both layers, both keys)。" -ForegroundColor Green
        Write-Host "    含义: 桌面版和从终端启动的 Claude 都应该解锁 1M。重启后看 /context 分母应是 1000.0k。" -ForegroundColor DarkGray
        Write-Host "    Meaning: both desktop and terminal-launched Claude should be unlocked; /context should read 1000.0k after restart." -ForegroundColor DarkGray
    } elseif ($settingsOk) {
        Write-Host "判定 / VERDICT: 1M 已解锁 (settings.json 两键齐全, 对桌面版足够) / ACTIVE (settings.json)。" -ForegroundColor Green
        Write-Host "    含义: 桌面版的 Claude 应已解锁; 终端启动的 Claude 没设 env, 但 settings.json 这一层 CLI 也会读, 通常照样生效。" -ForegroundColor DarkGray
        Write-Host "    Meaning: desktop Claude should be unlocked; CLI also reads settings.json so it likely works too." -ForegroundColor DarkGray
    } elseif ($settingsPartial) {
        $miss = if (-not $sCtx) { $VAR_CTX } else { $VAR_NOCMP }
        Write-Host "判定 / VERDICT: settings.json 里缺一键 ($miss), 不会生效 (两键缺一不可) / INCOMPLETE — missing $miss。" -ForegroundColor Red
        Write-Host "    含义: 缺一个键, 覆盖路径不会触发, 桌面版仍会被截回 200k。重跑 Install 即可。" -ForegroundColor DarkGray
        Write-Host "    Meaning: missing one key; the override path won't trigger; desktop will stay at 200k. Re-run Install." -ForegroundColor DarkGray
    } elseif ($envOk) {
        Write-Host "判定 / VERDICT: 仅用户环境变量两键齐全; 桌面版可能不读, 建议补 settings.json / PARTIAL (env only)。" -ForegroundColor Yellow
        Write-Host "    含义: 从终端启动的 Claude 应解锁; 桌面版多半不读用户环境变量, 仍可能是 200k。" -ForegroundColor DarkGray
        Write-Host "    Meaning: terminal-launched Claude should be unlocked; the desktop app likely won't read user env vars, so it may still show 200k." -ForegroundColor DarkGray
    } elseif ($envPartial) {
        $emiss = if (-not $eCtx) { $VAR_CTX } else { $VAR_NOCMP }
        Write-Host "判定 / VERDICT: 用户环境变量缺一键 ($emiss); 不会生效 / PARTIAL (env incomplete)。" -ForegroundColor Yellow
        Write-Host "    含义: 终端那一层缺一个键, 覆盖路径不会触发。建议直接跑 Install (两层都写)。" -ForegroundColor DarkGray
        Write-Host "    Meaning: env layer is missing a key; the override path won't trigger. Just run Install (both layers)." -ForegroundColor DarkGray
    } else {
        Write-Host "判定 / VERDICT: 未启用 / NOT enabled。" -ForegroundColor Red
        Write-Host "    含义: 两层都没设, 1M 没有解锁, /context 分母会是 200.0k。运行 Install 即可。" -ForegroundColor DarkGray
        Write-Host "    Meaning: neither layer is set; 1M is not unlocked; /context will show 200.0k. Run Install to fix." -ForegroundColor DarkGray
    }
    Write-Host "确认生效: 重启桌面版后看 /context 或左下角分母 — 1000.0k = 成功, 200.0k = 未生效。" -ForegroundColor DarkGray
}

function Show-NextSteps {
    Write-Host ""
    Write-Host "下一步 / NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  即便本次只改了一层, 也建议两边都重启一次, 避免遗留进程拿到旧值。" -ForegroundColor Yellow
    Write-Host "  Even if you only touched one layer this run, restart BOTH to avoid lingering stale processes." -ForegroundColor Yellow
    Write-Host "  桌面版:  托盘图标右键 -> 完全退出 (不是只关窗口), 再重新打开。" -ForegroundColor Yellow
    Write-Host "  Desktop: Tray icon -> Quit completely (not just close window), then reopen." -ForegroundColor Yellow
    Write-Host "  CLI:     关掉当前终端窗口, 新开一个再用 claude (所有终端最好都关一遍)。" -ForegroundColor Yellow
    Write-Host "           Close this terminal (ideally close ALL of them), open a NEW one, run claude." -ForegroundColor Yellow
    Write-Host "  验证 / verify: 重开后看 /context 或左下角分母 — 1000.0k = 成功, 200.0k = 失败。" -ForegroundColor Yellow
}

function Show-Caveat {
    Write-Host ""
    Write-Host "重要副作用 / IMPORTANT SIDE EFFECT:" -ForegroundColor DarkYellow
    Write-Host "  本工具用 DISABLE_COMPACT=1 来绕过门禁, 这会彻底关闭 auto-compact。" -ForegroundColor DarkYellow
    Write-Host "  上下文满了不再自动总结, 需手动 /compact 或开新会话。这是解锁 1M 的代价。" -ForegroundColor DarkYellow
    Write-Host "  This uses DISABLE_COMPACT=1 to bypass the gate, which turns OFF auto-compact." -ForegroundColor DarkYellow
    Write-Host "  When context fills up it won't auto-summarize; run /compact or start fresh." -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "  另外: 能否解锁取决于你的桌面版版本与渠道是否真支持 1M。若分母仍是 200k," -ForegroundColor DarkYellow
    Write-Host "  见 README 的「失败排查」(可先把两个值都改成 `"true`" 再试)。" -ForegroundColor DarkYellow
    Write-Host "  Also: success depends on your desktop build/channel actually supporting 1M." -ForegroundColor DarkYellow
    Write-Host "  If it stays 200k, see README troubleshooting (try the literal `"true`" first)." -ForegroundColor DarkYellow
}

function Show-RollbackTail {
    Write-Host ""
    Write-Host "回滚完成。重开终端 / 完全退出并重开桌面版 后生效。" -ForegroundColor Yellow
    Write-Host "Rollback done. Relaunch terminal / fully quit+reopen the desktop app to take effect." -ForegroundColor Yellow
    Write-Host "提示 / NOTE: 回滚同时关闭了 DISABLE_COMPACT, auto-compact 会恢复 (仅对被回滚的那一层)。" -ForegroundColor DarkGray
}

# ============================ 菜单 / MENU ============================

function Show-Menu {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Claude 1M Context Unlock  $VERSION" -ForegroundColor Cyan
    if ($DryRun) { Write-Host " [DRY-RUN 模式: 不会真正写盘 / no changes written]" -ForegroundColor Magenta }
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " 配置文件 / config: $SettingsPath"
    Write-Host ""
    Write-Host "  [1] Install (both)               两层都写 (推荐)"
    Write-Host "      `-> 一键搞定, 桌面版和终端两边都解锁 1M"
    Write-Host "      `-> One-click: unlock 1M for both desktop and terminal."
    Write-Host ""
    Write-Host "  [2] Install settings.json only   只写 settings.json"
    Write-Host "      `-> 只让桌面版的 Claude 解锁 1M, 不动系统环境变量"
    Write-Host "      `-> Unlock the desktop Claude only; leave system env vars alone."
    Write-Host ""
    Write-Host "  [3] Install user env vars only   只写用户环境变量"
    Write-Host "      `-> 只让从终端启动的 Claude 解锁 1M, 不改配置文件"
    Write-Host "      `-> Unlock terminal-launched Claude only; don't touch the config file."
    Write-Host ""
    Write-Host "  [4] Status                       查看当前状态"
    Write-Host "      `-> 看现在是不是已经解锁, 没解锁缺哪个"
    Write-Host "      `-> Check whether it's unlocked now and which key (if any) is missing."
    Write-Host ""
    Write-Host "  [5] Rollback (both)              两层都回滚 (回到 200k)"
    Write-Host "      `-> 一键还原, 把所有改动撤掉, 回到默认 200k"
    Write-Host "      `-> One-click revert: undo everything, back to the default 200k."
    Write-Host ""
    Write-Host "  [6] Rollback settings.json only  只回滚 settings.json"
    Write-Host "      `-> 只撤掉对桌面版的解锁, 用户环境变量保留"
    Write-Host "      `-> Undo the desktop unlock only; keep user env vars as they are."
    Write-Host ""
    Write-Host "  [7] Rollback user env vars only  只回滚用户环境变量"
    Write-Host "      `-> 只撤掉对终端的解锁, 配置文件保留"
    Write-Host "      `-> Undo the terminal unlock only; keep the config file as it is."
    Write-Host ""
    Write-Host "  [Q] Quit                         退出"
    Write-Host ""
}

# 非交互模式 / Non-interactive (AI agent) dispatch
if ($Action -ne "") {
    switch ($Action.ToLower()) {
        "install"           { Action-Install }
        "install-settings"  { Action-InstallSettings }
        "install-env"       { Action-InstallEnv }
        "status"            { Action-Status }
        "rollback"          { Action-Rollback }
        "rollback-settings" { Action-RollbackSettings }
        "rollback-env"      { Action-RollbackEnv }
    }
    exit 0
}

# 主循环 / main loop
while ($true) {
    Show-Menu
    $choice = (Read-Host "请选择 / Choose").Trim().ToUpper()
    switch ($choice) {
        "1" { Action-Install }
        "2" { Action-InstallSettings }
        "3" { Action-InstallEnv }
        "4" { Action-Status }
        "5" { Action-Rollback }
        "6" { Action-RollbackSettings }
        "7" { Action-RollbackEnv }
        "Q" { Write-Host "再见 / Bye."; break }
        default { Write-Host "无效选择 / invalid choice: $choice" -ForegroundColor Red }
    }
    if ($choice -eq "Q") { break }
}
