import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Menu, Timer, Calendar, BarChart3, Settings } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Tab } from '@/types';

// Views
import FocusView from './views/FocusView';
import PlanView from './views/PlanView';
import StatsView from './views/StatsView';
import SettingsView from './views/SettingsView';

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>('focus');

  const renderView = () => {
    switch (activeTab) {
      case 'focus':
        return <FocusView onComplete={() => {}} />;
      case 'plan':
        return <PlanView />;
      case 'stats':
        return <StatsView />;
      case 'settings':
        return <SettingsView />;
      default:
        return <FocusView onComplete={() => {}} />;
    }
  };

  const navItems = [
    { id: 'focus' as Tab, label: '专注', icon: Timer },
    { id: 'plan' as Tab, label: '计划', icon: Calendar },
    { id: 'stats' as Tab, label: '统计', icon: BarChart3 },
    { id: 'settings' as Tab, label: '设置', icon: Settings },
  ];

  return (
    <div className="min-h-screen bg-surface selection:bg-primary-container text-on-surface">
      {/* Top App Bar */}
      <header className="fixed top-0 left-0 w-full h-20 px-8 flex justify-between items-center z-50 bg-surface/80 backdrop-blur-md">
        <div className="flex items-center">
          <button className="text-primary hover:opacity-60 transition-opacity">
            <Menu className="w-6 h-6" />
          </button>
        </div>
        
        <h1 className="font-headline font-light tracking-[0.2em] text-xl text-primary">轻舟</h1>
        
        <div className="w-10 h-10" /> {/* Spacer to keep title centered */}
      </header>

      {/* Main Content Area */}
      <main className="relative z-0">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, scale: 0.99, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 1.01, y: -10 }}
            transition={{ duration: 0.4, ease: [0.645, 0.045, 0.355, 1] }}
            className="w-full"
          >
            {renderView()}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 w-full bg-surface/80 backdrop-blur-lg border-t border-outline/5 px-6 pt-3 pb-safe flex justify-around items-center z-50">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={cn(
                "flex flex-col items-center gap-1.5 py-1 px-4 transition-all duration-300 transform active:scale-90",
                isActive ? "text-primary" : "text-outline hover:text-primary/60"
              )}
            >
              <div className="relative">
                <Icon className={cn("w-6 h-6", isActive && "fill-current")} />
                {isActive && (
                  <motion.div 
                    layoutId="nav-dot"
                    className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1 h-1 bg-primary rounded-full"
                  />
                )}
              </div>
              <span className={cn(
                "text-[10px] font-label font-medium tracking-wider uppercase",
                isActive ? "opacity-100" : "opacity-60"
              )}>
                {item.label}
              </span>
            </button>
          );
        })}
      </nav>

      {/* Global Grainy Texture Overlay */}
      <div 
        className="fixed inset-0 pointer-events-none opacity-[0.02] mix-blend-overlay z-[100]"
        style={{ backgroundImage: "url('https://grainy-gradients.vercel.app/noise.svg')" }}
      />
    </div>
  );
}
