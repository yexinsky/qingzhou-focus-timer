# 轻舟 - 沉浸式学习专注器

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41-blue" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Android%20|%20iOS-green" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

> 一款面向考研党的沉浸式番茄钟，专注、计划、复盘三位一体，用极简设计助力高效学习。

## 预览

<p align="center">
  <img src="https://via.placeholder.com/300x600/FAFAFA/426464?text=专注界面" width="200" alt="专注界面">
  <img src="https://via.placeholder.com/300x600/FAFAFA/516074?text=计划界面" width="200" alt="计划界面">
  <img src="https://via.placeholder.com/300x600/FAFAFA/426464?text=统计界面" width="200" alt="统计界面">
</p>

## 特性

### 专注计时
- 🎯 番茄工作法，25/45/60/90 分钟多档时长
- 🎨 学科专属色环，圆环颜色随任务学科变化
- ⏸️ 播放/暂停/放弃三按钮控制
- 🔒 严苛模式，中途放弃需二次确认

### 任务规划
- 📋 今日待办，支持政治/英语/数学/专业课/其他
- 🎨 学科色彩系统，绛红·雾霾蓝·豆绿·灰紫
- ➕ 底部弹窗快速添加任务
- 👆 左滑删除，任务自动沉底

### 统计复盘
- 📊 日/周/月多维度切换
- 📈 专注时长与番茄数卡片
- 📉 周柱状图 + 学科占比环形图
- 📝 最近专注记录流水

### 设计语言
- 🌙 莫兰迪低饱和色调，高级灰质感
- ✨ 极致留白 + 轻量卡片化布局
- 🔄 物理阻尼动效，克制不花哨
- 📱 支持日间/夜间模式自动切换

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.41 | 跨平台原生渲染 |
| 状态 | flutter_riverpod | 轻量响应式状态管理 |
| 存储 | hive + shared_preferences | 本地数据持久化 |
| 图表 | fl_chart | 柱状图/环形图 |
| 路由 | go_router | 声明式路由，滑入转场 |
| 图标 | phosphor_flutter | 1.5px 线性图标 |

## 安装

```bash
# 克隆项目
git clone https://github.com/your-username/qingzhou_focus.git
cd qingzhou_focus

# 安装依赖
flutter pub get

# 运行项目
flutter run
```

## 项目结构

```
lib/
├── core/                    # 核心工具
│   ├── theme/              # 主题与颜色
│   └── utils/              # 工具函数
├── data/                   # 数据层
│   ├── models/             # 数据模型
│   └── repositories/       # 数据仓库
├── providers/              # Riverpod 状态提供者
├── router/                 # go_router 路由配置
└── views/                  # 页面视图
    ├── focus/              # 专注计时页
    ├── plan/               # 任务规划页
    ├── stats/              # 统计复盘页
    └── settings/           # 设置页
```

## AI 辅助声明

本应用使用 AI（Claude Code）辅助开发，代码结构、设计实现及文档整理均有 AI 参与。

## License

MIT License - 详见 [LICENSE](LICENSE) 文件
