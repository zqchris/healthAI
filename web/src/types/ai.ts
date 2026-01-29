// AI 服务类型定义

export type AIProvider = 'openai' | 'anthropic';

export interface AIConfig {
  provider: AIProvider;
  apiKey: string;
  model: string;
  baseURL?: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
}

export interface AIResponse {
  content: string;
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

// OpenAI API 请求格式
export interface OpenAIRequest {
  model: string;
  messages: {
    role: string;
    content: string;
  }[];
  stream?: boolean;
  temperature?: number;
  max_tokens?: number;
}

// Anthropic API 请求格式
export interface AnthropicRequest {
  model: string;
  messages: {
    role: string;
    content: string;
  }[];
  system?: string;
  stream?: boolean;
  max_tokens: number;
}

// 默认配置
export const DEFAULT_CONFIGS: Record<AIProvider, Omit<AIConfig, 'apiKey'>> = {
  openai: {
    provider: 'openai',
    model: 'gpt-4o',
    baseURL: 'https://api.openai.com/v1/chat/completions',
  },
  anthropic: {
    provider: 'anthropic',
    model: 'claude-3-5-sonnet-20241022',
    baseURL: 'https://api.anthropic.com/v1/messages',
  },
};
