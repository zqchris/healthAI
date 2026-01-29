import { useState, useRef, useEffect } from 'react';
import { Send, Settings, Loader2 } from 'lucide-react';
import { HealthSummary } from '../types/health';
import { ChatMessage } from '../types/ai';
import { aiService } from '../services/aiService';

interface ChatPageProps {
  healthData: HealthSummary;
  isConfigured: boolean;
  onOpenSettings: () => void;
}

export function ChatPage({ healthData, isConfigured, onOpenSettings }: ChatPageProps) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [streamingContent, setStreamingContent] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // 自动滚动到底部
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, streamingContent]);

  // 发送消息
  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      content: input.trim(),
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);
    setStreamingContent('');

    try {
      const healthContext = aiService.generateHealthContext(healthData);

      const response = await aiService.sendMessage(
        [...messages, userMessage],
        healthContext,
        (chunk) => {
          setStreamingContent(prev => prev + chunk);
        }
      );

      const assistantMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.content,
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, assistantMessage]);
      setStreamingContent('');
    } catch (error) {
      const errorMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: `抱歉，发生了错误: ${error instanceof Error ? error.message : '未知错误'}`,
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, errorMessage]);
      setStreamingContent('');
    } finally {
      setIsLoading(false);
    }
  };

  // 处理回车发送
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // 未配置 API 时显示提示
  if (!isConfigured) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-6 text-center">
        <div className="w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center mb-4">
          <Settings className="w-8 h-8 text-gray-400" />
        </div>
        <h2 className="text-lg font-semibold text-gray-800">配置 AI 服务</h2>
        <p className="text-gray-500 mt-2 max-w-sm">
          请先配置您的 AI API 密钥，支持 OpenAI 和 Anthropic
        </p>
        <button
          onClick={onOpenSettings}
          className="mt-6 btn-primary"
        >
          前往设置
        </button>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      {/* 头部 */}
      <header className="bg-white border-b border-gray-100 px-4 py-4">
        <h1 className="text-xl font-bold text-gray-800">AI 健康顾问</h1>
        <p className="text-sm text-gray-400 mt-1">基于您的健康数据提供个性化建议</p>
      </header>

      {/* 消息列表 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && !streamingContent && (
          <div className="text-center py-12">
            <p className="text-gray-400">开始与 AI 健康顾问对话</p>
            <div className="mt-4 space-y-2">
              {[
                '我的睡眠质量如何？',
                '根据我的数据给一些健康建议',
                '我的运动量够吗？',
              ].map((suggestion, index) => (
                <button
                  key={index}
                  onClick={() => setInput(suggestion)}
                  className="block w-full max-w-xs mx-auto px-4 py-2 text-sm text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}

        {/* 流式响应显示 */}
        {streamingContent && (
          <div className="flex justify-start">
            <div className="max-w-[85%] px-4 py-3 rounded-2xl bg-white border border-gray-100 shadow-sm">
              <p className="text-gray-800 whitespace-pre-wrap">{streamingContent}</p>
              <span className="inline-block w-2 h-4 bg-primary-500 animate-pulse ml-1" />
            </div>
          </div>
        )}

        {/* 加载指示器 */}
        {isLoading && !streamingContent && (
          <div className="flex justify-start">
            <div className="px-4 py-3 rounded-2xl bg-white border border-gray-100">
              <Loader2 className="w-5 h-5 text-gray-400 animate-spin" />
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* 输入区域 */}
      <div className="bg-white border-t border-gray-100 p-4">
        <div className="flex items-end gap-2 max-w-2xl mx-auto">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="输入您的健康问题..."
            rows={1}
            className="flex-1 input resize-none max-h-32"
            style={{ minHeight: '44px' }}
          />
          <button
            onClick={handleSend}
            disabled={!input.trim() || isLoading}
            className="btn-primary p-3"
          >
            <Send className="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
  );
}

// 消息气泡组件
function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`
          max-w-[85%] px-4 py-3 rounded-2xl
          ${isUser
            ? 'bg-primary-500 text-white'
            : 'bg-white border border-gray-100 shadow-sm text-gray-800'}
        `}
      >
        <p className="whitespace-pre-wrap">{message.content}</p>
        <p className={`text-xs mt-1 ${isUser ? 'text-primary-100' : 'text-gray-400'}`}>
          {message.timestamp.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}
        </p>
      </div>
    </div>
  );
}
