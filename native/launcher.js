ObjC.import('Foundation');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

function helperPath() {
  const environment = $.NSProcessInfo.processInfo.environment;
  const resources = environment.objectForKey('CODEX_SWITCHER_RESOURCES');
  if (resources) return ObjC.unwrap(resources) + '/switcher.sh';
  const bundle = $.NSBundle.mainBundle.bundlePath.js;
  return bundle + '/Contents/Resources/switcher.sh';
}
function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
function runHelper(action, one, two, three) {
  let command = shellQuote(helperPath()) + ' ' + shellQuote(action);
  if (one) command += ' ' + shellQuote(one);
  if (two) command += ' ' + shellQuote(two);
  if (three) command += ' ' + shellQuote(three);
  return app.doShellScript(command);
}
function autoUpdate() {
  try {
    const result = runHelper('auto-update', '', '').trim();
    if (result.indexOf('UPDATED|') === 0) return true;
  } catch (_) {
    // Update checks are best-effort; an offline launch must still work.
  }
  return false;
}
function ensureKey(account, name) {
  try { runHelper('has-key', account, ''); return; } catch (_) {}
  const response = app.displayDialog('第一次使用，请输入 ' + name + ' API Key。\n密钥只会保存在 macOS 钥匙串。', {
    defaultAnswer: '', hiddenAnswer: true, buttons: ['取消', '保存'], defaultButton: '保存', cancelButton: '取消', withTitle: 'Codex 模型一键切换'
  });
  if (!response.textReturned) throw new Error('未输入 API Key');
  runHelper('save-key', account, response.textReturned);
}
function ensureCCSwitch() {
  try { return runHelper('cc-status', '', ''); } catch (_) {}
  app.displayDialog('SiliconFlow 需要 CC Switch 做协议转换。\n\n点击“安装”后，将从 farion1231/cc-switch 官方 GitHub 下载最新版，并安装到你的“个人应用程序”文件夹。', {
    buttons: ['取消', '安装'], defaultButton: '安装', cancelButton: '取消', withTitle: '安装官方 CC Switch', withIcon: 'caution'
  });
  const path = runHelper('install-cc-switch', '', '');
  app.displayDialog('CC Switch 已安装。下一步会将 SiliconFlow API Key 交给本机 CC Switch，并打开供应商导入确认页。', {
    buttons: ['继续'], defaultButton: '继续', withTitle: '安装完成'
  });
  return path;
}
function importSiliconFlow() {
  ensureCCSwitch();
  ensureKey('siliconflow', 'SiliconFlow');
  const key = runHelper('get-key', 'siliconflow', '').trim();
  let models = [];
  try {
    models = runHelper('list-siliconflow-models', '', '').split('\n').map(x => x.trim()).filter(Boolean);
  } catch (_) {}
  const recommended = ['deepseek-ai/DeepSeek-V4-Flash', 'Pro/deepseek-ai/DeepSeek-V4'];
  recommended.forEach(x => { if (models.indexOf(x) < 0) models.unshift(x); });
  models.unshift('手动输入完整模型 ID…');
  const selected = app.chooseFromList(models, {
    withPrompt: '选择 SiliconFlow 模型\n列表来自你的 SiliconFlow 账户；也可以手动输入模型 ID。',
    defaultItems: [models.indexOf('deepseek-ai/DeepSeek-V4-Flash') >= 0 ? 'deepseek-ai/DeepSeek-V4-Flash' : models[1]]
  });
  if (!selected) throw new Error('User canceled');
  let model = selected[0];
  if (model === '手动输入完整模型 ID…') {
    const answer = app.displayDialog('请粘贴 SiliconFlow 模型广场中的完整模型 ID。\n例如：deepseek-ai/DeepSeek-V4-Flash', {
      defaultAnswer: '', buttons: ['取消', '继续'], defaultButton: '继续', cancelButton: '取消', withTitle: 'SiliconFlow 模型 ID'
    });
    model = answer.textReturned.trim();
    if (!model || model.indexOf('/') < 1) throw new Error('模型 ID 无效，应为类似 deepseek-ai/DeepSeek-V4-Flash 的完整名称。');
  }
  runHelper('save-siliconflow-model', model, '');
  const params = [
    'resource=provider', 'app=codex', 'name=' + encodeURIComponent('SiliconFlow'),
    'homepage=' + encodeURIComponent('https://siliconflow.cn'),
    'endpoint=' + encodeURIComponent('https://api.siliconflow.cn/v1'),
    'apiKey=' + encodeURIComponent(key),
    'model=' + encodeURIComponent(model),
    'icon=siliconflow', 'enabled=true'
  ];
  app.openLocation('ccswitch://v1/import?' + params.join('&'));
  return model;
}
function globalMode() {
  const choices = ['OpenAI', 'DeepSeek V4 Flash', 'DeepSeek V4 Pro', 'SiliconFlow（需要本机兼容网关）', '恢复上一次配置'];
  const picked = app.chooseFromList(choices, {withPrompt: '切换当前 Codex：保留现有项目、聊天和权限；切换后请重启 Codex', defaultItems: ['OpenAI']});
  if (!picked) return;
  try {
    switch (picked[0]) {
      case 'OpenAI': runHelper('switch', 'openai', ''); break;
      case 'DeepSeek V4 Flash': ensureKey('deepseek', 'DeepSeek'); runHelper('switch', 'deepseek-flash', ''); break;
      case 'DeepSeek V4 Pro': ensureKey('deepseek', 'DeepSeek'); runHelper('switch', 'deepseek-pro', ''); break;
      case 'SiliconFlow（需要本机兼容网关）':
        const siliconModel = importSiliconFlow();
        app.displayDialog('CC Switch 已打开 SiliconFlow 导入页。\n\n已选模型：' + siliconModel + '\n\n请检查后点击“导入/确认”，并确认“路由总开关”和“Codex”已开启。完成后重启 Codex。', {buttons: ['好'], defaultButton: '好', withTitle: '最后一次确认'});
        return;
      case '恢复上一次配置': runHelper('restore', '', ''); break;
    }
    app.displayDialog('操作完成。请完全退出 Codex，然后重新打开。', {buttons: ['好'], defaultButton: '好', withTitle: 'Codex 模型一键切换'});
  } catch (e) {
    if (String(e).includes('User canceled')) return;
    app.displayDialog('操作失败：\n' + e, {buttons: ['好'], defaultButton: '好', withIcon: 'stop'});
  }
}

function independentMode() {
  const models = ['OpenAI GPT-5.6', 'DeepSeek V4 Flash', 'DeepSeek V4 Pro'];
  const picked = app.chooseFromList(models, {withPrompt: '选择这个独立 Codex 窗口使用的模型', defaultItems: ['OpenAI GPT-5.6']});
  if (!picked) return;
  let profile = 'openai';
  if (picked[0] === 'DeepSeek V4 Flash') profile = 'deepseek-flash';
  if (picked[0] === 'DeepSeek V4 Pro') profile = 'deepseek-pro';
  if (profile.indexOf('deepseek') === 0) ensureKey('deepseek', 'DeepSeek');

  const folder = app.chooseFolder({withPrompt: '选择这个窗口要打开的项目文件夹'});
  const projectPath = folder.toString();
  const mode = app.displayDialog('怎样打开这个项目？\n\n“安全 Worktree”会为 Git 项目建立独立副本，最适合两个模型同时工作。\n“共享原目录”会让两个窗口直接操作同一批文件。', {
    buttons: ['取消', '共享原目录', '安全 Worktree'], defaultButton: '安全 Worktree', cancelButton: '取消', withTitle: '独立 Codex 窗口'
  }).buttonReturned === '安全 Worktree' ? 'worktree' : 'shared';
  const result = runHelper('launch-session', profile, projectPath, mode).trim();
  app.displayDialog('新的 Codex 已在 Terminal 中启动。\n\n模型：' + picked[0] + '\n项目：' + projectPath + '\n方式：' + (mode === 'worktree' ? '安全 Worktree' : '共享原目录') + '\n\n这是独立新会话，不会显示桌面端旧聊天；旧项目和聊天请使用“当前 Codex 切换”。', {buttons: ['好'], defaultButton: '好', withTitle: '已启动'});
}

function run() {
  try {
    if (autoUpdate()) return;
    const modes = ['当前 Codex 切换（保留项目和聊天）', '新开独立 Codex 窗口（新聊天）'];
    const picked = app.chooseFromList(modes, {withPrompt: '选择使用方式', defaultItems: ['当前 Codex 切换（保留项目和聊天）']});
    if (!picked) return;
    if (picked[0] === '当前 Codex 切换（保留项目和聊天）') globalMode(); else independentMode();
  } catch (e) {
    if (String(e).includes('User canceled')) return;
    app.displayDialog('操作失败：\n' + e, {buttons: ['好'], defaultButton: '好', withIcon: 'stop'});
  }
}
