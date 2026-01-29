import { HealthSummary } from '../types/health';
import {
  Footprints,
  Heart,
  Moon,
  Flame,
  TrendingUp,
  TrendingDown,
  Minus,
  RefreshCw,
} from 'lucide-react';

interface DashboardPageProps {
  healthData: HealthSummary;
  onClearData: () => void;
}

export function DashboardPage({ healthData, onClearData }: DashboardPageProps) {
  const { averages, steps, heartRate, sleep, activity } = healthData;

  // 计算趋势（最近7天 vs 之前7天）
  const calculateTrend = (data: number[]) => {
    if (data.length < 14) return 'neutral';
    const recent = data.slice(0, 7).reduce((a, b) => a + b, 0) / 7;
    const previous = data.slice(7, 14).reduce((a, b) => a + b, 0) / 7;
    if (recent > previous * 1.05) return 'up';
    if (recent < previous * 0.95) return 'down';
    return 'neutral';
  };

  const stepsTrend = calculateTrend(steps.slice(0, 14).map(s => s.steps));
  const sleepTrend = calculateTrend(sleep.slice(0, 14).map(s => s.duration));

  // 最近7天数据
  const recentSteps = steps.slice(0, 7);
  const recentSleep = sleep.slice(0, 7);
  const _recentActivity = activity.slice(0, 7); // 保留供将来使用
  void _recentActivity;
  const restingHR = heartRate.filter(h => h.context === 'resting').slice(0, 7);

  return (
    <div className="h-full overflow-y-auto">
      {/* 头部 */}
      <header className="bg-white border-b border-gray-100 px-4 py-4 sticky top-0 z-10">
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold text-gray-800">健康数据</h1>
          <button
            onClick={onClearData}
            className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100"
            title="重新上传数据"
          >
            <RefreshCw className="w-5 h-5" />
          </button>
        </div>
        <p className="text-sm text-gray-400 mt-1">
          数据范围: {healthData.dateRange.start.toLocaleDateString('zh-CN')} - {healthData.dateRange.end.toLocaleDateString('zh-CN')}
        </p>
      </header>

      <main className="p-4 pb-20 space-y-4">
        {/* 概览卡片 */}
        <div className="grid grid-cols-2 gap-4">
          {/* 步数 */}
          <StatCard
            icon={Footprints}
            iconColor="text-blue-500"
            iconBg="bg-blue-100"
            label="日均步数"
            value={averages.dailySteps.toLocaleString()}
            unit="步"
            trend={stepsTrend}
          />

          {/* 心率 */}
          <StatCard
            icon={Heart}
            iconColor="text-red-500"
            iconBg="bg-red-100"
            label="静息心率"
            value={averages.restingHeartRate || '--'}
            unit="次/分"
          />

          {/* 睡眠 */}
          <StatCard
            icon={Moon}
            iconColor="text-purple-500"
            iconBg="bg-purple-100"
            label="平均睡眠"
            value={averages.sleepDuration ? (averages.sleepDuration / 60).toFixed(1) : '--'}
            unit="小时"
            trend={sleepTrend}
          />

          {/* 活动能量 */}
          <StatCard
            icon={Flame}
            iconColor="text-orange-500"
            iconBg="bg-orange-100"
            label="日均消耗"
            value={averages.activeEnergy || '--'}
            unit="千卡"
          />
        </div>

        {/* 最近7天步数 */}
        <section className="card">
          <h2 className="font-semibold text-gray-800 mb-4">最近7天步数</h2>
          <div className="space-y-3">
            {recentSteps.length > 0 ? (
              recentSteps.map((item, index) => (
                <div key={index} className="flex items-center justify-between">
                  <span className="text-sm text-gray-500">
                    {item.date.toLocaleDateString('zh-CN', { weekday: 'short', month: 'short', day: 'numeric' })}
                  </span>
                  <div className="flex items-center gap-2">
                    <div className="w-32 h-2 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-blue-500 rounded-full"
                        style={{ width: `${Math.min(item.steps / 100, 100)}%` }}
                      />
                    </div>
                    <span className="text-sm font-medium text-gray-700 w-16 text-right">
                      {item.steps.toLocaleString()}
                    </span>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-gray-400 text-sm">暂无步数数据</p>
            )}
          </div>
        </section>

        {/* 最近睡眠 */}
        <section className="card">
          <h2 className="font-semibold text-gray-800 mb-4">最近睡眠记录</h2>
          <div className="space-y-3">
            {recentSleep.length > 0 ? (
              recentSleep.map((item, index) => (
                <div key={index} className="flex items-center justify-between">
                  <span className="text-sm text-gray-500">
                    {item.date.toLocaleDateString('zh-CN', { weekday: 'short', month: 'short', day: 'numeric' })}
                  </span>
                  <div className="flex items-center gap-3">
                    {item.stages && (
                      <div className="flex gap-1 text-xs">
                        <span className="px-1.5 py-0.5 bg-purple-100 text-purple-600 rounded">
                          深睡 {(item.stages.deep / 60).toFixed(1)}h
                        </span>
                        <span className="px-1.5 py-0.5 bg-blue-100 text-blue-600 rounded">
                          REM {(item.stages.rem / 60).toFixed(1)}h
                        </span>
                      </div>
                    )}
                    <span className="text-sm font-medium text-gray-700">
                      {(item.duration / 60).toFixed(1)}h
                    </span>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-gray-400 text-sm">暂无睡眠数据</p>
            )}
          </div>
        </section>

        {/* 心率记录 */}
        {restingHR.length > 0 && (
          <section className="card">
            <h2 className="font-semibold text-gray-800 mb-4">静息心率</h2>
            <div className="space-y-3">
              {restingHR.map((item, index) => (
                <div key={index} className="flex items-center justify-between">
                  <span className="text-sm text-gray-500">
                    {item.date.toLocaleDateString('zh-CN', { weekday: 'short', month: 'short', day: 'numeric' })}
                  </span>
                  <span className="text-sm font-medium text-gray-700">
                    {item.bpm} 次/分
                  </span>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* 数据统计 */}
        <section className="card bg-gray-50">
          <h2 className="font-semibold text-gray-800 mb-2">数据统计</h2>
          <p className="text-sm text-gray-500">
            共解析 {healthData.totalRecords.toLocaleString()} 条健康记录
          </p>
        </section>
      </main>
    </div>
  );
}

// 统计卡片组件
interface StatCardProps {
  icon: React.ElementType;
  iconColor: string;
  iconBg: string;
  label: string;
  value: string | number;
  unit: string;
  trend?: 'up' | 'down' | 'neutral';
}

function StatCard({ icon: Icon, iconColor, iconBg, label, value, unit, trend }: StatCardProps) {
  return (
    <div className="card">
      <div className="flex items-start justify-between">
        <div className={`w-10 h-10 rounded-xl ${iconBg} flex items-center justify-center`}>
          <Icon className={`w-5 h-5 ${iconColor}`} />
        </div>
        {trend && (
          <div className={`
            ${trend === 'up' ? 'text-green-500' : trend === 'down' ? 'text-red-500' : 'text-gray-400'}
          `}>
            {trend === 'up' && <TrendingUp className="w-4 h-4" />}
            {trend === 'down' && <TrendingDown className="w-4 h-4" />}
            {trend === 'neutral' && <Minus className="w-4 h-4" />}
          </div>
        )}
      </div>
      <div className="mt-3">
        <p className="text-2xl font-bold text-gray-800">{value}</p>
        <p className="text-xs text-gray-400 mt-0.5">{label} · {unit}</p>
      </div>
    </div>
  );
}
