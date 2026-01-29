# 健康 AI 助手开发计划

## 概述

本项目已从 iOS 原生应用转型为 **Web 应用**，采用纯前端技术栈，支持通过浏览器解析 Apple Health 导出数据并提供 AI 健康分析。

### 技术方案变更原因

1. **开发便捷性**: 可在手机上使用 AI 辅助开发，无需 Mac/Xcode
2. **跨平台**: 一次开发，所有平台可用
3. **部署简单**: Vercel 一键部署，无需 App Store 审核
4. **隐私保护**: 纯前端处理，数据不出浏览器

---

## 当前架构

```
┌─────────────────────────────────────────────────────────────┐
│                      用户浏览器                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  1. 上传 Apple Health 导出的 ZIP 文件                │   │
│  │  2. 浏览器本地解析 XML (JSZip + DOMParser)          │   │
│  │  3. 健康数据存储在内存中                             │   │
│  │  4. 用户配置的 API Key 存储在 localStorage          │   │
│  │  5. 直接调用 AI API (OpenAI/Anthropic)             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ↑
              Vercel 只托管静态文件
```

---

## 技术栈

| 类别 | 技术选择 |
|------|----------|
| 框架 | React 18 + TypeScript |
| 构建 | Vite |
| 样式 | Tailwind CSS |
| 图标 | Lucide React |
| 数据解析 | JSZip + DOMParser |
| 部署 | Vercel |

---

## 开发阶段

### 阶段 1: 项目重构 ✅ 已完成

- [x] 归档 iOS 原生代码
- [x] 创建 Web 项目结构
- [x] 配置 Vite + React + TypeScript
- [x] 配置 Tailwind CSS
- [x] 创建基础组件

### 阶段 2: 核心功能 ✅ 已完成

- [x] Apple Health XML 解析器
  - [x] ZIP 文件解压
  - [x] XML 解析与数据提取
  - [x] 支持步数、心率、睡眠、活动等数据
  - [x] 数据聚合与统计

- [x] AI 服务集成
  - [x] OpenAI API 集成
  - [x] Anthropic API 集成
  - [x] 流式响应支持
  - [x] 健康数据上下文生成

- [x] 用户界面
  - [x] 数据上传页面
  - [x] 健康数据仪表板
  - [x] AI 聊天页面
  - [x] 设置页面

### 阶段 3: 优化与部署 - 进行中

- [x] Vercel 部署配置
- [x] PWA 基础配置 (manifest.json)
- [ ] PWA 完整支持 (Service Worker)
- [ ] 应用图标设计
- [ ] 深色模式支持
- [ ] 更多数据可视化图表

### 阶段 4: 功能增强 - 计划中

- [ ] 数据导出功能 (JSON/CSV)
- [ ] 历史对话记录保存
- [ ] 多语言支持
- [ ] 健康报告生成
- [ ] 更多健康数据类型支持

---

## 文件结构

```
web/
├── src/
│   ├── components/          # 通用组件
│   │   └── TabBar.tsx       # 底部导航栏
│   ├── pages/               # 页面组件
│   │   ├── UploadPage.tsx   # 数据上传
│   │   ├── DashboardPage.tsx # 数据仪表板
│   │   ├── ChatPage.tsx     # AI 对话
│   │   └── SettingsPage.tsx # 设置
│   ├── services/            # 服务层
│   │   ├── healthParser.ts  # 健康数据解析
│   │   └── aiService.ts     # AI API 服务
│   ├── types/               # TypeScript 类型
│   │   ├── health.ts        # 健康数据类型
│   │   └── ai.ts            # AI 服务类型
│   ├── App.tsx              # 根组件
│   ├── main.tsx             # 入口文件
│   └── index.css            # 全局样式
├── public/
│   └── manifest.json        # PWA 配置
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── vercel.json              # Vercel 部署配置
```

---

## 部署指南

### 方式 1: Vercel 部署 (推荐)

1. 将代码推送到 GitHub
2. 在 [vercel.com](https://vercel.com) 导入项目
3. 设置:
   - **Root Directory**: `web`
   - **Framework Preset**: Vite
4. 点击 Deploy

### 方式 2: 本地运行

```bash
cd web
npm install
npm run dev
```

### 方式 3: 其他静态托管

```bash
cd web
npm install
npm run build
# 将 dist/ 目录部署到任意静态托管服务
```

---

## 原 iOS 版本

iOS 原生代码已归档至 `archive/ios-native/` 目录，包含:
- HealthKit 深度集成
- SwiftUI 界面
- Core Data 持久化
- 完整的 MVVM 架构

如需恢复 iOS 开发，可参考归档代码。

---

## 后续规划

1. **短期** (1-2周)
   - 完善 PWA 支持
   - 添加深色模式
   - 优化移动端体验

2. **中期** (1个月)
   - 增加数据可视化图表
   - 支持更多健康数据类型
   - 对话历史持久化

3. **长期**
   - 考虑添加可选的后端服务
   - 健康报告 PDF 导出
   - 多用户数据对比
