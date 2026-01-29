# 健康 AI 助手

基于 AI 的健康数据分析工具，通过解析 Apple Health 导出数据，提供个性化健康建议。

## 特点

- **隐私优先**: 所有数据在浏览器本地处理，不上传服务器
- **AI 驱动**: 支持 OpenAI (GPT-4o) 和 Anthropic (Claude 3.5)
- **跨平台**: 纯 Web 应用，手机/电脑均可使用
- **PWA 支持**: 可添加到主屏幕，像原生 App 一样使用

## 技术栈

- **前端框架**: React 18 + TypeScript
- **构建工具**: Vite
- **样式**: Tailwind CSS
- **部署**: Vercel (推荐) / 任意静态托管

## 快速开始

### 本地开发

```bash
cd web
npm install
npm run dev
```

访问 http://localhost:3000

### 部署到 Vercel

1. Fork 或 Clone 此仓库
2. 在 Vercel 中导入项目
3. 设置 Root Directory 为 `web`
4. 部署完成后即可访问

## 使用方法

1. **导出健康数据**
   - 打开 iPhone「健康」App
   - 点击右上角头像
   - 滚动到底部，选择「导出所有健康数据」
   - 等待导出完成，获得 ZIP 文件

2. **上传数据**
   - 打开健康 AI 助手网页
   - 上传导出的 ZIP 文件
   - 等待解析完成

3. **配置 AI**
   - 进入设置页面
   - 输入 OpenAI 或 Anthropic 的 API Key
   - 保存配置

4. **开始对话**
   - 切换到 AI 顾问页面
   - 向 AI 咨询健康相关问题

## 项目结构

```
healthAI/
├── web/                    # Web 应用源码
│   ├── src/
│   │   ├── components/     # React 组件
│   │   ├── pages/          # 页面组件
│   │   ├── services/       # 服务层（AI、数据解析）
│   │   ├── types/          # TypeScript 类型定义
│   │   └── utils/          # 工具函数
│   ├── public/             # 静态资源
│   └── package.json
├── docs/                   # 项目文档
│   ├── PRD.md              # 产品需求文档
│   └── plan.md             # 开发计划
├── archive/                # 归档代码
│   └── ios-native/         # 原 iOS 原生版本
└── README.md
```

## 数据隐私

- 健康数据仅在浏览器内存中处理
- API Key 存储在浏览器 localStorage
- 不使用后端服务器，不收集任何用户数据
- AI API 调用直接从浏览器发起

## 开发计划

详见 [docs/plan.md](docs/plan.md)

## License

MIT
