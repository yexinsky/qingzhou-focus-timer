import React from 'react';
import { motion } from 'motion/react';
import { GripVertical, Edit2, Play } from 'lucide-react';
import { cn } from '@/lib/utils';

export default function PlanView() {
  const tasks = [
    { id: '1', title: '政治考研大纲复习', color: 'bg-[#725959]', dotColor: 'bg-[#725959]/30' },
    { id: '2', title: '考研英语真题阅读 (2021)', color: 'bg-[#516074]', dotColor: 'bg-[#516074]/30' },
    { id: '3', title: '高等数学：泰勒展开', color: 'bg-[#426464]', dotColor: 'bg-[#426464]/30' },
  ];

  const durations = ['25分钟', '45分钟', '60分钟'];

  return (
    <div className="pt-24 pb-32 px-6 max-w-xl mx-auto min-h-screen">
      <section className="mb-12">
        <div className="flex justify-between items-end mb-6 px-2">
          <h2 className="font-headline font-light text-2xl tracking-tight text-on-surface">今日规划</h2>
          <span className="font-label text-xs tracking-widest text-on-surface-variant uppercase">还有3项任务</span>
        </div>
        
        <div className="space-y-4">
          {tasks.map((task) => (
            <motion.div 
              key={task.id}
              whileHover={{ x: 4 }}
              className="bg-surface-container-low p-5 rounded-xl flex items-center justify-between group cursor-pointer hover:bg-surface-container-high transition-colors duration-300"
            >
              <div className="flex items-center gap-4">
                <div className={cn("w-2.5 h-2.5 rounded-full", task.color)} />
                <span className="font-body text-on-surface font-medium tracking-wide">{task.title}</span>
              </div>
              <GripVertical className="w-5 h-5 text-outline-variant group-hover:text-primary transition-colors" />
            </motion.div>
          ))}
        </div>
      </section>

      <section className="mb-16">
        <div className="flex gap-3 overflow-x-auto no-scrollbar py-1">
          {durations.map((d, index) => (
            <button 
              key={d}
              className={cn(
                "flex-shrink-0 px-6 py-2.5 rounded-full font-label text-sm font-medium tracking-wide transition-all active:scale-95",
                index === 0 ? "bg-primary text-on-primary shadow-lg shadow-primary/10" : "bg-surface-container-low text-on-surface hover:bg-surface-container-high"
              )}
            >
              {d}
            </button>
          ))}
          <button className="flex-shrink-0 px-6 py-2.5 bg-surface-container-low text-on-surface rounded-full font-label text-sm font-medium tracking-wide hover:bg-surface-container-high transition-all active:scale-95 flex items-center gap-2">
            <Edit2 className="w-3.5 h-3.5" />
            自定义
          </button>
        </div>
      </section>

    </div>
  );
}
