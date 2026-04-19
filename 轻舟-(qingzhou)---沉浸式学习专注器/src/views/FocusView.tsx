import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { Pause, Play, Square, RotateCcw, CheckCircle2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface FocusViewProps {
  onComplete: (duration: number) => void;
}

export default function FocusView({ onComplete }: FocusViewProps) {
  const [timeLeft, setTimeLeft] = useState(25 * 60);
  const [totalTime, setTotalTime] = useState(25 * 60);
  const [isActive, setIsActive] = useState(false);
  const [sessionType, setSessionType] = useState<'focus' | 'break'>('focus');

  useEffect(() => {
    let interval: number | null = null;

    if (isActive && timeLeft > 0) {
      interval = window.setInterval(() => {
        setTimeLeft((prev) => prev - 1);
      }, 1000);
    } else if (timeLeft === 0) {
      setIsActive(false);
      onComplete(totalTime);
      // Logic for switching to break could be here or handled by parent
    }

    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isActive, timeLeft, totalTime, onComplete]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const toggleTimer = () => setIsActive(!isActive);

  const resetTimer = () => {
    setIsActive(false);
    setTimeLeft(totalTime);
  };

  const progress = ((totalTime - timeLeft) / totalTime) * 100;

  return (
    <div className="flex flex-col items-center justify-center min-h-[calc(100vh-160px)] px-6 relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 bg-primary/5 -z-10" />
      
      {/* Header Info */}
      <div className="mb-12 text-center">
        <motion.div 
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="inline-flex items-center px-4 py-1.5 bg-primary/10 rounded-full mb-6"
        >
          <span className="w-2 h-2 rounded-full bg-primary mr-2" />
          <span className="text-[10px] font-label font-bold tracking-[0.1em] text-primary uppercase">
            {isActive ? '进行中' : '待开始'}
          </span>
        </motion.div>
        <motion.h2 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="text-2xl md:text-3xl font-headline font-light text-on-surface tracking-tight"
        >
          刷真题100道 · <span className="text-primary font-medium">数学</span>
        </motion.h2>
      </div>

      {/* Main Timer Ring */}
      <div className="flex flex-col items-center gap-12">
        <div className="relative flex items-center justify-center w-[280px] h-[280px] md:w-[380px] md:h-[380px]">
          {/* Subtle Decorative Ring */}
          <svg className="absolute inset-0 w-full h-full -rotate-90 transform" viewBox="0 0 100 100">
            <circle 
              className="text-surface-container-high" 
              cx="50" cy="50" r="48" 
              fill="none" 
              stroke="currentColor" 
              strokeWidth="0.5" 
            />
            <motion.circle 
              className="text-primary" 
              cx="50" cy="50" r="48" 
              fill="none" 
              stroke="currentColor" 
              strokeWidth="1.5"
              strokeDasharray="301.59"
              animate={{ strokeDashoffset: 301.59 * (1 - progress / 100) }}
              transition={{ duration: 1, ease: "linear" }}
            />
          </svg>

          {/* Time Display */}
          <div className="text-center z-10">
            <motion.div 
              key={timeLeft}
              initial={{ scale: 0.98, opacity: 0.8 }}
              animate={{ scale: 1, opacity: 1 }}
              className="font-headline font-extralight text-[84px] md:text-[112px] leading-none text-on-surface tracking-[-0.02em]"
            >
              {formatTime(timeLeft)}
            </motion.div>
            <div className="mt-2 font-label text-[10px] tracking-[0.2em] text-outline uppercase">
              剩余时间
            </div>
          </div>
        </div>

        {/* Controls - Moved outside absolute positioning to avoid overlap */}
        <div className="flex flex-col items-center gap-16">
          <div className="flex items-center gap-6">
             <button 
              onClick={resetTimer}
              className="bg-surface-container-low w-12 h-12 rounded-full flex items-center justify-center text-outline hover:text-primary active:scale-90 transition-all"
            >
              <RotateCcw className="w-5 h-5" />
            </button>
            
            <button 
              onClick={toggleTimer}
              className="bg-primary shadow-[0_20px_40px_-10px_rgba(66,100,100,0.3)] w-18 h-18 rounded-full flex items-center justify-center text-white active:scale-95 transition-all"
            >
              {isActive ? <Pause className="w-9 h-9 fill-current" /> : <Play className="w-9 h-9 fill-current ml-1" />}
            </button>

            <button 
              className="bg-surface-container-low w-12 h-12 rounded-full flex items-center justify-center text-outline hover:text-red-500 active:scale-90 transition-all"
            >
              <Square className="w-5 h-5" />
            </button>
          </div>

          <div className="flex flex-col items-center gap-8">
            {/* Detail Text - Integrated into flow */}
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5 }}
              className="max-w-[280px] text-center space-y-2"
            >
              <p className="text-[10px] font-label text-outline/60 tracking-[0.2em] uppercase">今日目标</p>
              <p className="text-sm font-body text-on-surface-variant/80 leading-relaxed italic">
                “在晚操之前完成高等数学微积分模块的复习内容。”
              </p>
            </motion.div>

            <button className="font-label text-xs tracking-[0.2em] text-outline/40 hover:text-red-400 transition-colors duration-300 uppercase">
              放弃本次专注
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
