// Apple Health 数据类型定义

export interface HealthRecord {
  type: string;
  sourceName: string;
  sourceVersion?: string;
  unit?: string;
  creationDate: Date;
  startDate: Date;
  endDate: Date;
  value: number | string;
}

export interface StepData {
  date: Date;
  steps: number;
  source: string;
}

export interface HeartRateData {
  date: Date;
  bpm: number;
  context?: string; // 休息、运动等
}

export interface SleepData {
  date: Date;
  startTime: Date;
  endTime: Date;
  duration: number; // 分钟
  stages?: {
    deep: number;      // 深度睡眠分钟
    rem: number;       // REM 睡眠分钟
    core: number;      // 核心睡眠分钟
    awake: number;     // 清醒分钟
  };
}

export interface ActivityData {
  date: Date;
  activeEnergy: number;     // 活动能量 kcal
  exerciseMinutes: number;  // 运动分钟
  standHours: number;       // 站立小时
  distance?: number;        // 距离 米
  flightsClimbed?: number;  // 爬楼层数
}

export interface BodyData {
  date: Date;
  weight?: number;      // 体重 kg
  height?: number;      // 身高 cm
  bmi?: number;         // BMI
  bodyFat?: number;     // 体脂率 %
}

export interface VitalSignsData {
  date: Date;
  respiratoryRate?: number;    // 呼吸率
  oxygenSaturation?: number;   // 血氧 %
  bloodPressureSystolic?: number;   // 收缩压
  bloodPressureDiastolic?: number;  // 舒张压
  bodyTemperature?: number;    // 体温 ℃
}

// 健康数据汇总
export interface HealthSummary {
  // 基本信息
  dateRange: {
    start: Date;
    end: Date;
  };
  totalRecords: number;

  // 各类数据
  steps: StepData[];
  heartRate: HeartRateData[];
  sleep: SleepData[];
  activity: ActivityData[];
  body: BodyData[];
  vitalSigns: VitalSignsData[];

  // 统计数据
  averages: {
    dailySteps: number;
    restingHeartRate: number;
    sleepDuration: number;
    activeEnergy: number;
  };
}

// Apple Health XML 中的数据类型标识符
export const HealthKitTypes = {
  // 活动
  STEP_COUNT: 'HKQuantityTypeIdentifierStepCount',
  DISTANCE_WALKING_RUNNING: 'HKQuantityTypeIdentifierDistanceWalkingRunning',
  FLIGHTS_CLIMBED: 'HKQuantityTypeIdentifierFlightsClimbed',
  ACTIVE_ENERGY: 'HKQuantityTypeIdentifierActiveEnergyBurned',
  EXERCISE_TIME: 'HKQuantityTypeIdentifierAppleExerciseTime',
  STAND_HOUR: 'HKCategoryTypeIdentifierAppleStandHour',

  // 心率
  HEART_RATE: 'HKQuantityTypeIdentifierHeartRate',
  RESTING_HEART_RATE: 'HKQuantityTypeIdentifierRestingHeartRate',
  HEART_RATE_VARIABILITY: 'HKQuantityTypeIdentifierHeartRateVariabilitySDNN',

  // 睡眠
  SLEEP_ANALYSIS: 'HKCategoryTypeIdentifierSleepAnalysis',

  // 身体测量
  BODY_MASS: 'HKQuantityTypeIdentifierBodyMass',
  HEIGHT: 'HKQuantityTypeIdentifierHeight',
  BMI: 'HKQuantityTypeIdentifierBodyMassIndex',
  BODY_FAT: 'HKQuantityTypeIdentifierBodyFatPercentage',

  // 生命体征
  RESPIRATORY_RATE: 'HKQuantityTypeIdentifierRespiratoryRate',
  OXYGEN_SATURATION: 'HKQuantityTypeIdentifierOxygenSaturation',
  BLOOD_PRESSURE_SYSTOLIC: 'HKQuantityTypeIdentifierBloodPressureSystolic',
  BLOOD_PRESSURE_DIASTOLIC: 'HKQuantityTypeIdentifierBloodPressureDiastolic',
  BODY_TEMPERATURE: 'HKQuantityTypeIdentifierBodyTemperature',
} as const;

// 睡眠阶段值
export const SleepStageValues = {
  IN_BED: 0,
  ASLEEP_UNSPECIFIED: 1,
  AWAKE: 2,
  ASLEEP_CORE: 3,
  ASLEEP_DEEP: 4,
  ASLEEP_REM: 5,
} as const;
