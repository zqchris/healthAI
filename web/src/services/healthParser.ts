/**
 * Apple Health XML 解析服务
 * 在浏览器中解析用户导出的健康数据，数据不会离开本地
 */

import JSZip from 'jszip';
import {
  HealthSummary,
  StepData,
  HeartRateData,
  SleepData,
  ActivityData,
  BodyData,
  VitalSignsData,
  HealthKitTypes,
  SleepStageValues,
} from '../types/health';

export class HealthParser {
  /**
   * 解析 Apple Health 导出的 ZIP 文件
   */
  async parseExportFile(file: File): Promise<HealthSummary> {
    const zip = await JSZip.loadAsync(file);

    // 列出所有文件，调试用
    const allFiles = Object.keys(zip.files);
    console.log('ZIP 文件内容:', allFiles);

    // 查找 export.xml 文件（支持多种可能的路径）
    let xmlFile = zip.file(/export\.xml$/i)[0];

    // 如果没找到，尝试其他可能的文件名
    if (!xmlFile) {
      xmlFile = zip.file(/导出\.xml$/i)[0];
    }
    if (!xmlFile) {
      // 查找任何 .xml 文件
      const xmlFiles = allFiles.filter(f => f.endsWith('.xml') && !f.includes('cda'));
      if (xmlFiles.length > 0) {
        xmlFile = zip.file(xmlFiles[0]) as JSZip.JSZipObject;
      }
    }

    if (!xmlFile) {
      throw new Error(`无法找到健康数据文件。ZIP 包含: ${allFiles.slice(0, 10).join(', ')}${allFiles.length > 10 ? '...' : ''}`);
    }

    const xmlContent = await xmlFile.async('string');
    return this.parseXML(xmlContent);
  }

  /**
   * 解析 XML 内容
   */
  private parseXML(xmlContent: string): HealthSummary {
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlContent, 'text/xml');

    // 检查解析错误
    const parseError = doc.querySelector('parsererror');
    if (parseError) {
      throw new Error('XML 解析失败，文件可能已损坏');
    }

    // 获取所有 Record 元素
    const records = doc.querySelectorAll('Record');

    // 初始化数据容器
    const steps: StepData[] = [];
    const heartRate: HeartRateData[] = [];
    const sleep: SleepData[] = [];
    const activity: ActivityData[] = [];
    const body: BodyData[] = [];
    const vitalSigns: VitalSignsData[] = [];

    // 用于聚合每日数据的临时存储
    const dailySteps = new Map<string, number>();
    const dailyActivity = new Map<string, ActivityData>();
    const sleepSessions = new Map<string, SleepData>();

    let minDate = new Date();
    let maxDate = new Date(0);

    // 遍历所有记录
    records.forEach((record) => {
      const type = record.getAttribute('type');
      const value = record.getAttribute('value');
      const startDateStr = record.getAttribute('startDate');
      const endDateStr = record.getAttribute('endDate');
      const sourceName = record.getAttribute('sourceName') || 'Unknown';

      if (!type || !startDateStr) return;

      const startDate = new Date(startDateStr);
      const endDate = endDateStr ? new Date(endDateStr) : startDate;
      const dateKey = startDate.toISOString().split('T')[0];

      // 更新日期范围
      if (startDate < minDate) minDate = startDate;
      if (endDate > maxDate) maxDate = endDate;

      switch (type) {
        case HealthKitTypes.STEP_COUNT:
          if (value) {
            const currentSteps = dailySteps.get(dateKey) || 0;
            dailySteps.set(dateKey, currentSteps + parseFloat(value));
          }
          break;

        case HealthKitTypes.HEART_RATE:
          if (value) {
            heartRate.push({
              date: startDate,
              bpm: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.RESTING_HEART_RATE:
          if (value) {
            heartRate.push({
              date: startDate,
              bpm: parseFloat(value),
              context: 'resting',
            });
          }
          break;

        case HealthKitTypes.SLEEP_ANALYSIS:
          if (value) {
            const sessionKey = `${dateKey}-${sourceName}`;
            const existing = sleepSessions.get(sessionKey);
            const duration = (endDate.getTime() - startDate.getTime()) / 60000; // 分钟

            if (!existing) {
              sleepSessions.set(sessionKey, {
                date: startDate,
                startTime: startDate,
                endTime: endDate,
                duration: 0,
                stages: { deep: 0, rem: 0, core: 0, awake: 0 },
              });
            }

            const session = sleepSessions.get(sessionKey)!;
            const stageValue = parseInt(value);

            // 更新睡眠时间范围
            if (startDate < session.startTime) session.startTime = startDate;
            if (endDate > session.endTime) session.endTime = endDate;

            // 根据阶段累加时间
            if (session.stages) {
              switch (stageValue) {
                case SleepStageValues.ASLEEP_DEEP:
                  session.stages.deep += duration;
                  session.duration += duration;
                  break;
                case SleepStageValues.ASLEEP_REM:
                  session.stages.rem += duration;
                  session.duration += duration;
                  break;
                case SleepStageValues.ASLEEP_CORE:
                case SleepStageValues.ASLEEP_UNSPECIFIED:
                  session.stages.core += duration;
                  session.duration += duration;
                  break;
                case SleepStageValues.AWAKE:
                  session.stages.awake += duration;
                  break;
              }
            }
          }
          break;

        case HealthKitTypes.ACTIVE_ENERGY:
          if (value) {
            const existing = dailyActivity.get(dateKey) || this.createEmptyActivityData(startDate);
            existing.activeEnergy += parseFloat(value);
            dailyActivity.set(dateKey, existing);
          }
          break;

        case HealthKitTypes.EXERCISE_TIME:
          if (value) {
            const existing = dailyActivity.get(dateKey) || this.createEmptyActivityData(startDate);
            existing.exerciseMinutes += parseFloat(value);
            dailyActivity.set(dateKey, existing);
          }
          break;

        case HealthKitTypes.DISTANCE_WALKING_RUNNING:
          if (value) {
            const existing = dailyActivity.get(dateKey) || this.createEmptyActivityData(startDate);
            existing.distance = (existing.distance || 0) + parseFloat(value);
            dailyActivity.set(dateKey, existing);
          }
          break;

        case HealthKitTypes.FLIGHTS_CLIMBED:
          if (value) {
            const existing = dailyActivity.get(dateKey) || this.createEmptyActivityData(startDate);
            existing.flightsClimbed = (existing.flightsClimbed || 0) + parseFloat(value);
            dailyActivity.set(dateKey, existing);
          }
          break;

        case HealthKitTypes.BODY_MASS:
          if (value) {
            body.push({
              date: startDate,
              weight: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.HEIGHT:
          if (value) {
            body.push({
              date: startDate,
              height: parseFloat(value) * 100, // 转换为 cm
            });
          }
          break;

        case HealthKitTypes.BMI:
          if (value) {
            body.push({
              date: startDate,
              bmi: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.BODY_FAT:
          if (value) {
            body.push({
              date: startDate,
              bodyFat: parseFloat(value) * 100, // 转换为百分比
            });
          }
          break;

        case HealthKitTypes.OXYGEN_SATURATION:
          if (value) {
            vitalSigns.push({
              date: startDate,
              oxygenSaturation: parseFloat(value) * 100,
            });
          }
          break;

        case HealthKitTypes.RESPIRATORY_RATE:
          if (value) {
            vitalSigns.push({
              date: startDate,
              respiratoryRate: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.BLOOD_PRESSURE_SYSTOLIC:
          if (value) {
            vitalSigns.push({
              date: startDate,
              bloodPressureSystolic: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.BLOOD_PRESSURE_DIASTOLIC:
          if (value) {
            vitalSigns.push({
              date: startDate,
              bloodPressureDiastolic: parseFloat(value),
            });
          }
          break;

        case HealthKitTypes.BODY_TEMPERATURE:
          if (value) {
            vitalSigns.push({
              date: startDate,
              bodyTemperature: parseFloat(value),
            });
          }
          break;
      }
    });

    // 转换每日步数数据
    dailySteps.forEach((stepCount, dateKey) => {
      steps.push({
        date: new Date(dateKey),
        steps: Math.round(stepCount),
        source: 'Apple Health',
      });
    });

    // 转换活动数据
    dailyActivity.forEach((data) => {
      activity.push(data);
    });

    // 转换睡眠数据
    sleepSessions.forEach((session) => {
      if (session.duration > 0) {
        sleep.push(session);
      }
    });

    // 按日期排序
    steps.sort((a, b) => b.date.getTime() - a.date.getTime());
    heartRate.sort((a, b) => b.date.getTime() - a.date.getTime());
    sleep.sort((a, b) => b.date.getTime() - a.date.getTime());
    activity.sort((a, b) => b.date.getTime() - a.date.getTime());
    body.sort((a, b) => b.date.getTime() - a.date.getTime());
    vitalSigns.sort((a, b) => b.date.getTime() - a.date.getTime());

    // 计算平均值
    const averages = this.calculateAverages(steps, heartRate, sleep, activity);

    return {
      dateRange: { start: minDate, end: maxDate },
      totalRecords: records.length,
      steps,
      heartRate,
      sleep,
      activity,
      body,
      vitalSigns,
      averages,
    };
  }

  private createEmptyActivityData(date: Date): ActivityData {
    return {
      date,
      activeEnergy: 0,
      exerciseMinutes: 0,
      standHours: 0,
    };
  }

  private calculateAverages(
    steps: StepData[],
    heartRate: HeartRateData[],
    sleep: SleepData[],
    activity: ActivityData[]
  ) {
    const recentDays = 30;
    const now = new Date();
    const cutoff = new Date(now.getTime() - recentDays * 24 * 60 * 60 * 1000);

    const recentSteps = steps.filter((s) => s.date >= cutoff);
    const recentHeartRate = heartRate.filter((h) => h.date >= cutoff && h.context === 'resting');
    const recentSleep = sleep.filter((s) => s.date >= cutoff);
    const recentActivity = activity.filter((a) => a.date >= cutoff);

    return {
      dailySteps: recentSteps.length > 0
        ? Math.round(recentSteps.reduce((sum, s) => sum + s.steps, 0) / recentSteps.length)
        : 0,
      restingHeartRate: recentHeartRate.length > 0
        ? Math.round(recentHeartRate.reduce((sum, h) => sum + h.bpm, 0) / recentHeartRate.length)
        : 0,
      sleepDuration: recentSleep.length > 0
        ? Math.round(recentSleep.reduce((sum, s) => sum + s.duration, 0) / recentSleep.length)
        : 0,
      activeEnergy: recentActivity.length > 0
        ? Math.round(recentActivity.reduce((sum, a) => sum + a.activeEnergy, 0) / recentActivity.length)
        : 0,
    };
  }
}

export const healthParser = new HealthParser();
