import { useState, useEffect } from 'react';
import { HealthSummary } from './types/health';
import { aiService } from './services/aiService';
import { UploadPage } from './pages/UploadPage';
import { DashboardPage } from './pages/DashboardPage';
import { ChatPage } from './pages/ChatPage';
import { SettingsPage } from './pages/SettingsPage';
import { TabBar } from './components/TabBar';

type TabType = 'dashboard' | 'chat' | 'settings';

function App() {
  const [healthData, setHealthData] = useState<HealthSummary | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [isConfigured, setIsConfigured] = useState(false);

  useEffect(() => {
    setIsConfigured(aiService.isConfigured());
  }, []);

  // 如果没有健康数据，显示上传页面
  if (!healthData) {
    return (
      <UploadPage
        onDataLoaded={(data) => {
          setHealthData(data);
          setActiveTab('dashboard');
        }}
      />
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* 主内容区 */}
      <main className="flex-1 overflow-hidden">
        {activeTab === 'dashboard' && (
          <DashboardPage
            healthData={healthData}
            onClearData={() => setHealthData(null)}
          />
        )}
        {activeTab === 'chat' && (
          <ChatPage
            healthData={healthData}
            isConfigured={isConfigured}
            onOpenSettings={() => setActiveTab('settings')}
          />
        )}
        {activeTab === 'settings' && (
          <SettingsPage
            onConfigSaved={() => setIsConfigured(true)}
            onClearData={() => setHealthData(null)}
          />
        )}
      </main>

      {/* 底部导航 */}
      <TabBar activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}

export default App;
