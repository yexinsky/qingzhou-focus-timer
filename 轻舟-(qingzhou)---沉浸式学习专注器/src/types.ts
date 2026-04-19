export type Tab = 'focus' | 'plan' | 'stats' | 'settings';

export interface Task {
  id: string;
  title: string;
  category: string;
  color: string;
  completed: boolean;
}

export interface FocusSession {
  id: string;
  taskId: string;
  startTime: number;
  duration: number; // in seconds
  type: 'focus' | 'break';
}

export interface DailyStats {
  day: string;
  duration: number; // in minutes
}

export interface SubjectStat {
  subject: string;
  percentage: number;
  color: string;
}
