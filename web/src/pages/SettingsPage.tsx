import { useState, useEffect } from 'react';
import { Key, Globe, Check, Trash2, ExternalLink } from 'lucide-react';
import { AIConfig, AIProvider, DEFAULT_CONFIGS } from '../types/ai';
import { aiService } from '../services/aiService';

interface SettingsPageProps {
  onConfigSaved: () => void;
  onClearData: () => void;
}

export function SettingsPage({ onConfigSaved, onClearData }: SettingsPageProps) {
  const [provider, setProvider] = useState<AIProvider>('openai');
  const [apiKey, setApiKey] = useState('');
  const [model, setModel] = useState('');
  const [baseURL, setBaseURL] = useState('');
  const [isSaved, setIsSaved] = useState(false);
  const [showClearConfirm, setShowClearConfirm] = useState(false);

  // 加载已保存的配置
  useEffect(() => {
    const config = aiService.getConfig();
    if (config) {
      setProvider(config.provider);
      setApiKey(config.apiKey);
      setModel(config.model);
      setBaseURL(config.baseURL || '');
    }
  }, []);

  // 切换提供商时更新默认值
  useEffect(() => {
    const defaults = DEFAULT_CONFIGS[provider];
    setModel(defaults.model);
    if (!baseURL || baseURL === DEFAULT_CONFIGS.openai.baseURL || baseURL === DEFAULT_CONFIGS.anthropic.baseURL) {
      setBaseURL(defaults.baseURL || '');
    }
  }, [provider]);

  const handleSave = () => {
    const config: AIConfig = {
      provider,
      apiKey,
      model,
      baseURL: baseURL || undefined,
    };

    aiService.saveConfig(config);
    setIsSaved(true);
    onConfigSaved();

    setTimeout(() => setIsSaved(false), 2000);
  };

  const handleClearData = () => {
    setShowClearConfirm(false);
    onClearData();
  };

  return (
    <div className="h-full overflow-y-auto">
      {/* 头部 */}
      <header className="bg-white border-b border-gray-100 px-4 py-4 sticky top-0 z-10">
        <h1 className="text-xl font-bold text-gray-800">设置</h1>
      </header>

      <main className="p-4 pb-20 space-y-6 max-w-lg mx-auto">
        {/* AI 服务配置 */}
        <section className="card">
          <h2 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
            <Key className="w-5 h-5 text-gray-400" />
            AI 服务配置
          </h2>

          {/* 提供商选择 */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-600 mb-2">
              AI 提供商
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setProvider('openai')}
                className={`px-4 py-3 rounded-lg border-2 transition-colors ${
                  provider === 'openai'
                    ? 'border-primary-500 bg-primary-50 text-primary-700'
                    : 'border-gray-200 text-gray-600 hover:border-gray-300'
                }`}
              >
                <span className="font-medium">OpenAI</span>
                <p className="text-xs mt-1 opacity-70">GPT-4o</p>
              </button>
              <button
                onClick={() => setProvider('anthropic')}
                className={`px-4 py-3 rounded-lg border-2 transition-colors ${
                  provider === 'anthropic'
                    ? 'border-primary-500 bg-primary-50 text-primary-700'
                    : 'border-gray-200 text-gray-600 hover:border-gray-300'
                }`}
              >
                <span className="font-medium">Anthropic</span>
                <p className="text-xs mt-1 opacity-70">Claude 3.5</p>
              </button>
            </div>
          </div>

          {/* API Key */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-600 mb-2">
              API Key
            </label>
            <input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder={provider === 'openai' ? 'sk-...' : 'sk-ant-...'}
              className="input"
            />
            <p className="text-xs text-gray-400 mt-1">
              密钥仅存储在您的浏览器中，不会上传到服务器
            </p>
          </div>

          {/* 模型 */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-600 mb-2">
              模型
            </label>
            <input
              type="text"
              value={model}
              onChange={(e) => setModel(e.target.value)}
              className="input"
            />
          </div>

          {/* 自定义 API 地址 */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-600 mb-2 flex items-center gap-1">
              <Globe className="w-4 h-4" />
              API 地址 (可选)
            </label>
            <input
              type="text"
              value={baseURL}
              onChange={(e) => setBaseURL(e.target.value)}
              placeholder="使用默认地址"
              className="input"
            />
            <p className="text-xs text-gray-400 mt-1">
              留空使用官方 API，或填写代理地址
            </p>
          </div>

          {/* 保存按钮 */}
          <button
            onClick={handleSave}
            disabled={!apiKey}
            className="w-full btn-primary flex items-center justify-center gap-2"
          >
            {isSaved ? (
              <>
                <Check className="w-5 h-5" />
                已保存
              </>
            ) : (
              '保存配置'
            )}
          </button>
        </section>

        {/* 获取 API Key 的帮助链接 */}
        <section className="card">
          <h2 className="font-semibold text-gray-800 mb-4">如何获取 API Key</h2>
          <div className="space-y-3">
            <a
              href="https://platform.openai.com/api-keys"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <span className="text-gray-700">OpenAI API Keys</span>
              <ExternalLink className="w-4 h-4 text-gray-400" />
            </a>
            <a
              href="https://console.anthropic.com/settings/keys"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <span className="text-gray-700">Anthropic API Keys</span>
              <ExternalLink className="w-4 h-4 text-gray-400" />
            </a>
          </div>
        </section>

        {/* 数据管理 */}
        <section className="card">
          <h2 className="font-semibold text-gray-800 mb-4 flex items-center gap-2">
            <Trash2 className="w-5 h-5 text-gray-400" />
            数据管理
          </h2>

          {showClearConfirm ? (
            <div className="p-4 bg-red-50 rounded-lg">
              <p className="text-red-700 text-sm mb-3">
                确定要清除已上传的健康数据吗？这将返回到上传页面。
              </p>
              <div className="flex gap-2">
                <button
                  onClick={handleClearData}
                  className="flex-1 px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600"
                >
                  确认清除
                </button>
                <button
                  onClick={() => setShowClearConfirm(false)}
                  className="flex-1 btn-secondary"
                >
                  取消
                </button>
              </div>
            </div>
          ) : (
            <button
              onClick={() => setShowClearConfirm(true)}
              className="w-full px-4 py-2 text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors"
            >
              清除健康数据
            </button>
          )}
        </section>

        {/* 关于 */}
        <section className="card bg-gray-50">
          <h2 className="font-semibold text-gray-800 mb-2">关于</h2>
          <p className="text-sm text-gray-500">
            健康 AI 助手 v1.0.0
          </p>
          <p className="text-xs text-gray-400 mt-2">
            您的健康数据仅在浏览器本地处理，不会上传到任何服务器。
          </p>
        </section>
      </main>
    </div>
  );
}
