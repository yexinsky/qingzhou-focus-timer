import React from 'react';
import { motion } from 'motion/react';
import { Sparkles, Timer, Lightbulb } from 'lucide-react';
import { BarChart, Bar, XAxis, ResponsiveContainer, Cell, Tooltip } from 'recharts';
import { cn } from '@/lib/utils';

export default function StatsView() {
  const weeklyData = [
    { name: '周一', value: 60 },
    { name: '周二', value: 90 },
    { name: '周三', value: 75 },
    { name: '周四', value: 120, active: true },
    { name: '周五', value: 50 },
    { name: '周六', value: 30 },
    { name: '周日', value: 45 },
  ];

  const subjects = [
    { name: '英语', value: 45, color: '#516074' },
    { name: '政治', value: 25, color: '#725959' },
    { name: '数学', value: 15, color: '#426464' },
    { name: '专业课', value: 15, color: '#dde4e5' },
  ];

  return (
    <div className="pt-24 pb-32 px-8 max-w-lg mx-auto min-h-screen">
      <nav className="flex justify-around items-center mb-10 px-4">
        {['日', '周', '月'].map((tab) => (
          <div key={tab} className="flex flex-col items-center gap-1 cursor-pointer group">
            <span className={cn(
              "text-sm font-medium transition-colors",
              tab === '周' ? "font-bold text-primary" : "text-outline group-hover:text-primary/60"
            )}>
              {tab}
            </span>
            {tab === '周' && <div className="h-0.5 w-6 bg-primary rounded-full" />}
          </div>
        ))}
      </nav>

      <div className="grid grid-cols-1 gap-6 mb-10">
        <section className="bg-surface-container-lowest rounded-xl p-8 shadow-[0_24px_48px_-12px_rgba(45,52,53,0.06)]">
          <div className="flex justify-between items-start mb-6">
            <h2 className="text-xs tracking-[0.1em] text-secondary/60 uppercase font-bold">总专注时长</h2>
            <Sparkles className="w-5 h-5 text-primary/40" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-6xl font-headline font-light text-primary">32</span>
            <span className="text-xl font-headline font-light text-primary/60">h</span>
            <span className="text-6xl font-headline font-light text-primary ml-2">45</span>
            <span className="text-xl font-headline font-light text-primary/60">m</span>
          </div>
          <p className="mt-4 text-xs text-secondary/50 font-medium tracking-wide">本周累计专注时长</p>
        </section>

        <section className="bg-surface-container-lowest rounded-xl p-8 shadow-[0_24px_48px_-12px_rgba(45,52,53,0.06)]">
          <div className="flex justify-between items-start mb-6">
            <h2 className="text-xs tracking-[0.1em] text-secondary/60 uppercase font-bold">番茄数</h2>
            <Timer className="w-5 h-5 text-secondary/40" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-6xl font-headline font-light text-on-surface">64</span>
            <span className="text-lg text-secondary/60 font-medium ml-2">个番茄</span>
          </div>
          <p className="mt-4 text-xs text-secondary/50 font-medium tracking-wide">平均每日 9.1 个时段</p>
        </section>
      </div>

      <section className="mb-12">
        <div className="flex justify-between items-end mb-8">
          <div>
            <h3 className="text-lg font-semibold text-on-surface mb-1">专注波动</h3>
            <p className="text-xs text-secondary/60">2月12日 - 2月18日</p>
          </div>
          <div className="flex gap-2">
            <div className="w-2 h-2 rounded-full bg-primary/20" />
            <div className="w-2 h-2 rounded-full bg-primary" />
          </div>
        </div>
        
        <div className="bg-surface-container-low rounded-xl p-6 h-48">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={weeklyData}>
              <Bar dataKey="value" radius={[6, 6, 6, 6]}>
                {weeklyData.map((entry, index) => (
                  <Cell 
                    key={`cell-${index}`} 
                    fill={entry.active ? '#426464' : '#b7dbdb'} 
                  />
                ))}
              </Bar>
              <XAxis 
                dataKey="name" 
                axisLine={false} 
                tickLine={false} 
                tick={{ fontSize: 10, fill: '#51607499', fontWeight: 700 }} 
                dy={10}
              />
              <Tooltip 
                cursor={{ fill: 'transparent' }}
                content={({ active, payload }) => {
                  if (active && payload && payload.length) {
                    return (
                      <div className="bg-white px-2 py-1 rounded shadow-sm border border-outline/10 text-[10px] text-primary font-bold">
                        {payload[0].value}m
                      </div>
                    );
                  }
                  return null;
                }}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="mb-12">
        <h3 className="text-lg font-semibold text-on-surface mb-8">学科分布</h3>
        <div className="flex items-center gap-10 overflow-hidden">
          <div className="relative w-36 h-36 flex items-center justify-center shrink-0">
             <svg className="w-full h-full transform -rotate-90">
                <circle className="text-secondary/10" cx="72" cy="72" r="64" fill="transparent" stroke="currentColor" strokeWidth="12" />
                {/* Simplified donut slice for demo background */}
                <circle 
                  className="text-primary" 
                  cx="72" cy="72" r="64" 
                  fill="transparent" 
                  stroke="currentColor" 
                  strokeWidth="14"
                  strokeDasharray="402"
                  strokeDashoffset="340"
                />
                <circle 
                  className="text-secondary" 
                  cx="72" cy="72" r="64" 
                  fill="transparent" 
                  stroke="currentColor" 
                  strokeWidth="14"
                  strokeDasharray="402"
                  strokeDashoffset="220"
                />
             </svg>
             <div className="absolute flex flex-col items-center">
               <span className="text-[10px] text-secondary/40 font-bold uppercase tracking-widest">主攻</span>
               <span className="text-lg font-headline font-light">英语</span>
             </div>
          </div>
          
          <div className="flex-1 space-y-4">
            {subjects.map((s) => (
              <div key={s.name} className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full" style={{ backgroundColor: s.color }} />
                <div className="flex-1">
                  <div className="flex justify-between items-baseline">
                    <span className="text-sm font-medium">{s.name}</span>
                    <span className="text-xs font-headline text-secondary/60">{s.value}%</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-primary/5 rounded-xl p-6 border border-primary/10">
        <div className="flex items-center gap-3 mb-3">
          <Lightbulb className="w-4 h-4 text-primary" />
          <h4 className="text-sm font-bold text-primary">学习洞察</h4>
        </div>
        <p className="text-sm text-primary/80 leading-relaxed">
          本周你的专注高峰出现在周四上午。英语学科的投入明显增加，建议下周保持这种平稳的产出节奏。
        </p>
      </section>
    </div>
  );
}
