import { useState, useCallback } from 'react';
import { Upload, AlertCircle, CheckCircle } from 'lucide-react';
import { healthParser } from '../services/healthParser';
import { HealthSummary } from '../types/health';

interface UploadPageProps {
  onDataLoaded: (data: HealthSummary) => void;
}

export function UploadPage({ onDataLoaded }: UploadPageProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string>('');

  const handleFile = useCallback(async (file: File) => {
    if (!file.name.endsWith('.zip')) {
      setError('请上传 Apple Health 导出的 ZIP 文件');
      return;
    }

    setIsLoading(true);
    setError(null);
    setProgress('正在解压文件...');

    try {
      setProgress('正在解析健康数据...');
      const data = await healthParser.parseExportFile(file);

      setProgress('解析完成!');
      setTimeout(() => {
        onDataLoaded(data);
      }, 500);
    } catch (e) {
      setError(e instanceof Error ? e.message : '解析文件时发生错误');
      setIsLoading(false);
    }
  }, [onDataLoaded]);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);

    const file = e.dataTransfer.files[0];
    if (file) {
      handleFile(file);
    }
  }, [handleFile]);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleFile(file);
    }
  }, [handleFile]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-primary-50 to-white flex flex-col">
      {/* 头部 */}
      <header className="pt-12 pb-6 px-6 text-center">
        <h1 className="text-2xl font-bold text-gray-800">健康 AI 助手</h1>
        <p className="text-gray-500 mt-2">上传您的 Apple Health 数据，获取 AI 健康分析</p>
      </header>

      {/* 主内容 */}
      <main className="flex-1 px-6 pb-12">
        <div className="max-w-md mx-auto">
          {/* 上传区域 */}
          <div
            onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={handleDrop}
            className={`
              relative border-2 border-dashed rounded-2xl p-8 text-center
              transition-all duration-200
              ${isDragging
                ? 'border-primary-500 bg-primary-50'
                : 'border-gray-200 bg-white hover:border-gray-300'}
              ${isLoading ? 'opacity-75 pointer-events-none' : ''}
            `}
          >
            <input
              type="file"
              accept=".zip"
              onChange={handleFileSelect}
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
              disabled={isLoading}
            />

            {isLoading ? (
              <div className="animate-fade-in">
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-primary-100 flex items-center justify-center">
                  <div className="w-8 h-8 border-3 border-primary-500 border-t-transparent rounded-full animate-spin" />
                </div>
                <p className="text-gray-600">{progress}</p>
              </div>
            ) : (
              <>
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-primary-100 flex items-center justify-center">
                  <Upload className="w-8 h-8 text-primary-500" />
                </div>
                <p className="text-gray-700 font-medium">拖放文件到此处</p>
                <p className="text-gray-400 text-sm mt-1">或点击选择文件</p>
                <p className="text-gray-300 text-xs mt-4">支持 Apple Health 导出的 ZIP 文件</p>
              </>
            )}
          </div>

          {/* 错误提示 */}
          {error && (
            <div className="mt-4 p-4 bg-red-50 border border-red-100 rounded-xl flex items-start gap-3 animate-fade-in">
              <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-red-700 font-medium">上传失败</p>
                <p className="text-red-600 text-sm mt-1">{error}</p>
              </div>
            </div>
          )}

          {/* 使用说明 */}
          <div className="mt-8 space-y-4">
            <h2 className="text-sm font-medium text-gray-500 uppercase tracking-wide">如何导出数据</h2>

            <div className="card">
              <ol className="space-y-4 text-sm text-gray-600">
                <li className="flex gap-3">
                  <span className="w-6 h-6 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center flex-shrink-0 font-medium">1</span>
                  <span>打开 iPhone 上的「健康」App</span>
                </li>
                <li className="flex gap-3">
                  <span className="w-6 h-6 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center flex-shrink-0 font-medium">2</span>
                  <span>点击右上角头像图标</span>
                </li>
                <li className="flex gap-3">
                  <span className="w-6 h-6 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center flex-shrink-0 font-medium">3</span>
                  <span>滚动到底部，点击「导出所有健康数据」</span>
                </li>
                <li className="flex gap-3">
                  <span className="w-6 h-6 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center flex-shrink-0 font-medium">4</span>
                  <span>将导出的 ZIP 文件上传到这里</span>
                </li>
              </ol>
            </div>

            {/* 隐私说明 */}
            <div className="flex items-start gap-3 p-4 bg-green-50 rounded-xl">
              <CheckCircle className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
              <div className="text-sm">
                <p className="text-green-700 font-medium">数据安全保障</p>
                <p className="text-green-600 mt-1">
                  您的健康数据仅在浏览器本地处理，不会上传到任何服务器。
                </p>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
