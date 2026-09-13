ObjC.import('Foundation');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

function helperPath() {
  const bundle = $.NSBundle.mainBundle.bundlePath.js;
  return bundle + '/Contents/Resources/switcher.sh';
}
function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
function runHelper(action, one, two) {
  let command = shellQuote(helperPath()) + ' ' + shellQuote(action);
  if (one) command += ' ' + shellQuote(one);
  if (two) command += ' ' + shellQuote(two);
  return app.doShellScript(command);
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
  const params = [
    'resource=provider', 'app=codex', 'name=' + encodeURIComponent('SiliconFlow'),
    'homepage=' + encodeURIComponent('https://siliconflow.cn'),
    'endpoint=' + encodeURIComponent('https://api.siliconflow.cn/v1'),
    'apiKey=' + encodeURIComponent(key),
    'model=' + encodeURIComponent('deepseek-ai/DeepSeek-V4-Flash'),
    'icon=siliconflow', 'enabled=true'
  ];
  app.openLocation('ccswitch://v1/import?' + params.join('&'));
}
function run() {
  const choices = ['OpenAI', 'DeepSeek V4 Flash', 'DeepSeek V4 Pro', 'SiliconFlow（需要本机兼容网关）', '恢复上一次配置'];
  const picked = app.chooseFromList(choices, {withPrompt: '选择要使用的模型（切换后请重启 Codex）', defaultItems: ['OpenAI']});
  if (!picked) return;
  try {
    switch (picked[0]) {
      case 'OpenAI': runHelper('switch', 'openai', ''); break;
      case 'DeepSeek V4 Flash': ensureKey('deepseek', 'DeepSeek'); runHelper('switch', 'deepseek-flash', ''); break;
      case 'DeepSeek V4 Pro': ensureKey('deepseek', 'DeepSeek'); runHelper('switch', 'deepseek-pro', ''); break;
      case 'SiliconFlow（需要本机兼容网关）':
        importSiliconFlow();
        app.displayDialog('CC Switch 已打开 SiliconFlow 导入页。\n\n请检查信息后点击“导入/确认”，并在 CC Switch 设置中确认“路由总开关”和“Codex”已开启。完成后重启 Codex。', {buttons: ['好'], defaultButton: '好', withTitle: '最后一次确认'});
        return;
      case '恢复上一次配置': runHelper('restore', '', ''); break;
    }
    app.displayDialog('操作完成。请完全退出 Codex，然后重新打开。', {buttons: ['好'], defaultButton: '好', withTitle: 'Codex 模型一键切换'});
  } catch (e) {
    if (String(e).includes('User canceled')) return;
    app.displayDialog('操作失败：\n' + e, {buttons: ['好'], defaultButton: '好', withIcon: 'stop'});
  }
}
