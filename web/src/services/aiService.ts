/**
 * AI 服务 - 支持 OpenAI 和 Anthropic
 * 直接从浏览器调用 API，API Key 存储在本地
 */

import { AIConfig, ChatMessage, AIResponse, AIProvider, DEFAULT_CONFIGS } from '../types/ai';
import { HealthSummary } from '../types/health';

const STORAGE_KEY = 'health_ai_config';

export class AIService {
  private config: AIConfig | null = null;

  constructor() {
    this.loadConfig();
  }

  /**
   * 从 localStorage 加载配置
   */
  loadConfig(): AIConfig | null {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        this.config = JSON.parse(saved);
        return this.config;
      }
    } catch (e) {
      console.error('加载 AI 配置失败:', e);
    }
    return null;
  }

  /**
   * 保存配置到 localStorage
   */
  saveConfig(config: AIConfig): void {
    this.config = config;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
  }

  /**
   * 获取当前配置
   */
  getConfig(): AIConfig | null {
    return this.config;
  }

  /**
   * 检查是否已配置
   */
  isConfigured(): boolean {
    return this.config !== null && this.config.apiKey.length > 0;
  }

  /**
   * 生成健康数据的系统提示词
   */
  generateHealthContext(summary: HealthSummary): string {
    const { averages, dateRange } = summary;
    const recentSteps = summary.steps.slice(0, 7);
    const recentSleep = summary.sleep.slice(0, 7);
    const recentHeartRate = summary.heartRate.filter(h => h.context === 'resting').slice(0, 7);

    return `你是一位专业的健康顾问 AI。用户已分享了他们的 Apple Health 数据，请基于这些数据提供个性化的健康建议。

## 用户健康数据概览

数据时间范围: ${dateRange.start.toLocaleDateString('zh-CN')} 至 ${dateRange.end.toLocaleDateString('zh-CN')}

### 近30天平均数据:
- 日均步数: ${averages.dailySteps.toLocaleString()} 步
- 静息心率: ${averages.restingHeartRate || '无数据'} 次/分钟
- 平均睡眠: ${averages.sleepDuration ? Math.round(averages.sleepDuration / 60 * 10) / 10 : '无数据'} 小时
- 日均活动能量: ${averages.activeEnergy} 千卡

### 最近7天步数:
${recentSteps.map(s => `- ${s.date.toLocaleDateString('zh-CN')}: ${s.steps.toLocaleString()} 步`).join('\n')}

### 最近7天睡眠:
${recentSleep.map(s => `- ${s.date.toLocaleDateString('zh-CN')}: ${Math.round(s.duration / 60 * 10) / 10} 小时${s.stages ? ` (深睡 ${Math.round(s.stages.deep / 60 * 10) / 10}h, REM ${Math.round(s.stages.rem / 60 * 10) / 10}h)` : ''}`).join('\n')}

${recentHeartRate.length > 0 ? `### 最近静息心率:
${recentHeartRate.map(h => `- ${h.date.toLocaleDateString('zh-CN')}: ${h.bpm} 次/分钟`).join('\n')}` : ''}

## 注意事项:
1. 基于用户的实际数据给出具体、个性化的建议
2. 如果发现数据异常，温和地提醒用户注意
3. 回答要简洁实用，避免过于专业的医学术语
4. 必要时建议用户咨询医生
5. 保持积极鼓励的语气`;
  }

  /**
   * 发送消息给 AI（支持流式响应）
   */
  async sendMessage(
    messages: ChatMessage[],
    healthContext?: string,
    onStream?: (chunk: string) => void
  ): Promise<AIResponse> {
    if (!this.config) {
      throw new Error('请先配置 AI API');
    }

    const { provider, apiKey, model, baseURL } = this.config;

    if (provider === 'openai') {
      return this.sendOpenAI(messages, healthContext, apiKey, model, baseURL, onStream);
    } else {
      return this.sendAnthropic(messages, healthContext, apiKey, model, baseURL, onStream);
    }
  }

  private async sendOpenAI(
    messages: ChatMessage[],
    healthContext: string | undefined,
    apiKey: string,
    model: string,
    baseURL: string | undefined,
    onStream?: (chunk: string) => void
  ): Promise<AIResponse> {
    const url = baseURL || DEFAULT_CONFIGS.openai.baseURL!;

    const apiMessages = [];
    if (healthContext) {
      apiMessages.push({ role: 'system', content: healthContext });
    }
    apiMessages.push(...messages.map(m => ({ role: m.role, content: m.content })));

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: apiMessages,
        stream: !!onStream,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`OpenAI API 错误: ${response.status} - ${error}`);
    }

    if (onStream && response.body) {
      return this.handleOpenAIStream(response.body, onStream);
    } else {
      const data = await response.json();
      return {
        content: data.choices[0].message.content,
        usage: data.usage ? {
          promptTokens: data.usage.prompt_tokens,
          completionTokens: data.usage.completion_tokens,
          totalTokens: data.usage.total_tokens,
        } : undefined,
      };
    }
  }

  private async handleOpenAIStream(
    body: ReadableStream<Uint8Array>,
    onStream: (chunk: string) => void
  ): Promise<AIResponse> {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let content = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n').filter(line => line.startsWith('data: '));

      for (const line of lines) {
        const data = line.slice(6);
        if (data === '[DONE]') continue;

        try {
          const parsed = JSON.parse(data);
          const delta = parsed.choices[0]?.delta?.content;
          if (delta) {
            content += delta;
            onStream(delta);
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    }

    return { content };
  }

  private async sendAnthropic(
    messages: ChatMessage[],
    healthContext: string | undefined,
    apiKey: string,
    model: string,
    baseURL: string | undefined,
    onStream?: (chunk: string) => void
  ): Promise<AIResponse> {
    const url = baseURL || DEFAULT_CONFIGS.anthropic.baseURL!;

    const apiMessages = messages
      .filter(m => m.role !== 'system')
      .map(m => ({ role: m.role, content: m.content }));

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model,
        messages: apiMessages,
        system: healthContext,
        max_tokens: 4096,
        stream: !!onStream,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Anthropic API 错误: ${response.status} - ${error}`);
    }

    if (onStream && response.body) {
      return this.handleAnthropicStream(response.body, onStream);
    } else {
      const data = await response.json();
      return {
        content: data.content[0].text,
        usage: data.usage ? {
          promptTokens: data.usage.input_tokens,
          completionTokens: data.usage.output_tokens,
          totalTokens: data.usage.input_tokens + data.usage.output_tokens,
        } : undefined,
      };
    }
  }

  private async handleAnthropicStream(
    body: ReadableStream<Uint8Array>,
    onStream: (chunk: string) => void
  ): Promise<AIResponse> {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let content = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n').filter(line => line.startsWith('data: '));

      for (const line of lines) {
        const data = line.slice(6);
        try {
          const parsed = JSON.parse(data);
          if (parsed.type === 'content_block_delta' && parsed.delta?.text) {
            content += parsed.delta.text;
            onStream(parsed.delta.text);
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    }

    return { content };
  }
}

export const aiService = new AIService();
