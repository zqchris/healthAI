import { LayoutDashboard, MessageCircle, Settings } from 'lucide-react';

type TabType = 'dashboard' | 'chat' | 'settings';

interface TabBarProps {
  activeTab: TabType;
  onTabChange: (tab: TabType) => void;
}

export function TabBar({ activeTab, onTabChange }: TabBarProps) {
  const tabs = [
    { id: 'dashboard' as const, label: '健康数据', icon: LayoutDashboard },
    { id: 'chat' as const, label: 'AI 顾问', icon: MessageCircle },
    { id: 'settings' as const, label: '设置', icon: Settings },
  ];

  return (
    <nav className="bg-white border-t border-gray-200 px-4 py-2 safe-area-pb">
      <div className="flex justify-around items-center max-w-lg mx-auto">
        {tabs.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => onTabChange(id)}
            className={`flex flex-col items-center py-1 px-3 rounded-lg transition-colors ${
              activeTab === id
                ? 'text-primary-500'
                : 'text-gray-400 hover:text-gray-600'
            }`}
          >
            <Icon className="w-6 h-6" />
            <span className="text-xs mt-1">{label}</span>
          </button>
        ))}
      </div>
    </nav>
  );
}
