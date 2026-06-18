// ============================================================================
//  Claude 1M Context Unlock  -  OPTIONAL settings checker
//  v1.0.0
//
//  Requires Node.js. OPTIONAL — the installer's "Status" menu already does this.
//  Use this only if you want a standalone, dependency-free read of the two keys.
//  需要 Node.js。可选——安装器的 Status 菜单已能查看, 这只是一个独立的纯读取版。
//
//  作用 / What it does:
//    Reads ~/.claude/settings.json (honoring CLAUDE_CONFIG_DIR) and reports whether
//    BOTH keys required to unlock the 1M context are present:
//      CLAUDE_CODE_MAX_CONTEXT_TOKENS  (any non-zero value)
//      DISABLE_COMPACT                 (truthy: 1/true/yes/on)
//    It does NOT touch the network and does NOT modify anything. Read-only.
//    读取 settings.json, 报告解锁 1M 所需的两个键是否齐全。不联网, 不改任何东西。
//
//  用法 / Usage:
//    node check-1m-context.js
//
//  说明 / Note: 这只检查 Claude Code 的"意图"(配置层)。真正是否解锁, 要重启桌面端后
//  看 /context 或左下角进度条分母: 1000.0k = 成功, 200.0k = 未生效。
//  This checks the CONFIG only. Whether 1M is truly unlocked must be confirmed by
//  restarting the desktop app and reading /context (1000.0k = ok, 200.0k = not).
// ============================================================================
const fs = require('fs');
const path = require('path');
const os = require('os');

const VAR_CTX = 'CLAUDE_CODE_MAX_CONTEXT_TOKENS';
const VAR_NOCMP = 'DISABLE_COMPACT';

function configDir() {
  if (process.env.CLAUDE_CONFIG_DIR && process.env.CLAUDE_CONFIG_DIR.trim() !== '') {
    return process.env.CLAUDE_CONFIG_DIR;
  }
  return path.join(os.homedir(), '.claude');
}

function isTruthy(v) {
  if (v === undefined || v === null) return false;
  return ['1', 'true', 'yes', 'on'].includes(String(v).trim().toLowerCase());
}
function ctxOk(v) {
  if (v === undefined || v === null) return false;
  const s = String(v).trim();
  return s !== '' && s !== '0';
}

const settingsPath = path.join(configDir(), 'settings.json');
console.log('--- settings.json (' + settingsPath + ') ---');

let env = {};
if (!fs.existsSync(settingsPath)) {
  console.log('  (文件不存在 / file does not exist)');
} else {
  let raw;
  try {
    raw = fs.readFileSync(settingsPath, 'utf8');
  } catch (e) {
    console.error('  [ERROR] 无法读取 / cannot read: ' + e.message);
    process.exit(1);
  }
  if (!raw || raw.trim() === '') {
    console.error('  [ERROR] 文件为空 / file is empty.');
    process.exit(1);
  }
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (e) {
    console.error('  [ERROR] 不是合法 JSON / not valid JSON: ' + e.message);
    process.exit(1);
  }
  env = (obj && typeof obj.env === 'object' && obj.env) ? obj.env : {};
  console.log('  ' + VAR_CTX + ' = ' + (VAR_CTX in env ? "'" + env[VAR_CTX] + "'" : '(未设/not set)'));
  console.log('  ' + VAR_NOCMP + ' = ' + (VAR_NOCMP in env ? "'" + env[VAR_NOCMP] + "'" : '(未设/not set)'));
}

const okCtx = ctxOk(env[VAR_CTX]);
const okNoCmp = isTruthy(env[VAR_NOCMP]);

console.log('');
if (okCtx && okNoCmp) {
  console.log('>>> VERDICT: 两键齐全, 1M 已配置 / ACTIVE (both keys present).');
} else if (okCtx || okNoCmp) {
  const miss = okCtx ? VAR_NOCMP : VAR_CTX;
  console.log('>>> VERDICT: 缺一键 (' + miss + '), 不会生效 (两键缺一不可) / INCOMPLETE — missing ' + miss + '.');
  process.exitCode = 2;
} else {
  console.log('>>> VERDICT: 未启用 / NOT enabled.');
  process.exitCode = 2;
}
console.log('确认真正生效 / confirm for real: 重启桌面端后看 /context 分母 — 1000.0k = ok, 200.0k = no.');
