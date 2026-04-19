import React from 'react';
import { motion } from 'motion/react';
import { Timer, Shield, Lock, AlertCircle, CheckCircle2, Minus, Plus } from 'lucide-react';
import { cn } from '@/lib/utils';

export default function SettingsView() {
  return (
    <div className="pt-32 pb-32 px-8 max-w-2xl mx-auto min-h-screen">
      <section className="mb-16">
        <h2 className="font-headline text-3xl font-light tracking-tight mb-4 text-on-surface">设置</h2>
        <p className="text-on-surface-variant font-light tracking-wide text-sm">定制您的沉浸式学习仪式</p>
      </section>

      <div className="space-y-12">
        {/* Timer Settings */}
        <section>
          <header className="flex justify-between items-center mb-6 pb-2 border-b border-surface-container-highest">
            <h3 className="font-headline text-sm font-medium uppercase tracking-[0.2em] text-secondary">专注计时</h3>
            <Timer className="w-5 h-5 text-outline-variant" />
          </header>
          <div className="space-y-10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-on-surface font-medium">默认专注时长</p>
                <p className="text-xs text-on-surface-variant mt-1">设置每次启动时的标准计时</p>
              </div>
              <div className="flex items-center space-x-6 bg-surface-container-low rounded-full px-4 py-2">
                <button className="w-8 h-8 flex items-center justify-center text-primary active:scale-90 transition-transform"><Minus className="w-4 h-4" /></button>
                <span className="font-headline font-light text-2xl w-8 text-center">25</span>
                <button className="w-8 h-8 flex items-center justify-center text-primary active:scale-90 transition-transform"><Plus className="w-4 h-4" /></button>
              </div>
            </div>
          </div>
        </section>

        {/* Discipline */}
        <section>
          <header className="flex justify-between items-center mb-6 pb-2 border-b border-surface-container-highest">
            <h3 className="font-headline text-sm font-medium uppercase tracking-[0.2em] text-secondary">自律增强</h3>
            <Shield className="w-5 h-5 text-outline-variant" />
          </header>
          <div className="space-y-10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-on-surface font-medium">严苛模式</p>
                <p className="text-xs text-on-surface-variant mt-1">计时期间禁止中途退出应用</p>
              </div>
              <div className="w-12 h-6 bg-primary rounded-full relative p-1 cursor-pointer">
                <div className="w-4 h-4 bg-white rounded-full absolute right-1" />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-on-surface font-medium">自动开启白噪音</p>
                <p className="text-xs text-on-surface-variant mt-1">沉浸入定后自动播放所选音频</p>
              </div>
              <div className="w-12 h-6 bg-surface-container-highest rounded-full relative p-1 cursor-pointer">
                <div className="w-4 h-4 bg-white rounded-full absolute left-1" />
              </div>
            </div>
          </div>
        </section>

        {/* Permissions */}
        <section>
          <header className="flex justify-between items-center mb-6 pb-2 border-b border-surface-container-highest">
            <h3 className="font-headline text-sm font-medium uppercase tracking-[0.2em] text-secondary">系统权限</h3>
            <Lock className="w-5 h-5 text-outline-variant" />
          </header>
          <div className="space-y-8">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-on-surface font-medium">通知提醒</p>
                <div className="flex items-center mt-2 space-x-2">
                  <AlertCircle className="w-4 h-4 text-red-500" />
                  <p className="text-xs text-red-500 font-medium">未授权：将无法接收专注结束提醒</p>
                </div>
              </div>
              <button className="text-primary font-medium text-sm tracking-wide">去开启</button>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-on-surface font-medium">触感反馈</p>
                <p className="text-xs text-secondary mt-1">已启用：提供细腻的物理反馈</p>
              </div>
              <CheckCircle2 className="w-5 h-5 text-primary" />
            </div>
          </div>
        </section>
      </div>

      <footer className="mt-24 mb-12 text-center">
        <p className="text-[10px] uppercase tracking-[0.3em] text-outline-variant font-headline">轻舟 版本 2.4.0</p>
        <div className="mt-4 flex justify-center space-x-8 text-xs text-on-surface-variant font-light">
          <a href="#" className="hover:text-primary transition-colors">隐私政策</a>
          <a href="#" className="hover:text-primary transition-colors">服务条款</a>
        </div>
      </footer>
    </div>
  );
}
