# 轻舟 - 沉浸式学习专注器

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-blue" alt="Flutter">
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-green" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

> 面向考研及长期备考用户的本地优先学习专注工具，覆盖计划、专注、统计和复盘。

## 功能

### 可靠专注计时

- 25、45、60、90 分钟固定倒计时。
- 支持灵活正计时，从 00:00 开始，可随时暂停、结束并按实际时长记录。
- 灵活计时与标准番茄分开统计，不会增加标准番茄数量或触发休息周期。
- 开始、暂停、恢复、重置与放弃。
- 按真实结束时间校正后台和锁屏期间的倒计时。
- 保存进行中的会话，应用重新启动后可恢复。
- 支持短休息、长休息和下一轮专注。
- 严苛模式会在放弃专注前进行二次确认。
- 计时结束支持本地通知和震动反馈。

### 费曼学习（文字版）

- 学习单元分为“输入理解”和“费曼输出”两段，默认 20/10 分钟。
- 输出计划时长不得低于输入时长的 50%，避免只输入不输出。
- 输入阶段结束后进入输出准备，输出阶段支持文字讲解草稿自动保存与重启恢复。
- 输出倒计时结束后可继续讲解并记录超时时间，不会强制截断。
- 讲解过程中可即时标记“卡壳”，记录阶段时间戳、关键词、原因、备注和严重程度。
- 提供按章节聚合的卡点热力排行，并可标记卡点是否解决。
- 复盘支持“已讲清楚、仍有盲点、需要重读”，系统会根据输出比例和卡点情况给出重读建议。
- 当前版本仅实现文字讲解，暂不包含录音、麦克风权限和音频存储。

### 多日任务规划

- 支持今天、明天和自选日期。
- 支持政治、英语、数学、专业课和其他分类。
- 支持新增、编辑、完成、删除和延期任务。
- 支持优先级、备注和预计番茄数。
- 根据专注记录展示任务实际完成的番茄数。
- 历史任务会被保留，不会在次日自动删除。

### 统计与历史

- 日、周、月三个统计维度。
- 专注时长、番茄数、趋势图和学科占比。
- 最近专注记录及完整历史记录页面。
- 支持删除单条专注记录，并同步更新统计数据。

### 院校排名

- 内置软科中国大学排名主榜（2026 年 590 所），完全离线可用。
- 按校名实时搜索，支持省份、院校类型和双一流/985/211 标签筛选。
- 列表展示名次、校名、标签、省市、类型与总分。
- 每年软科发布新榜后，运行 `dart run tool/fetch_bcur.dart` 更新内置数据并随版本发布。

### 数据管理

- 导出版本化 JSON 备份并通过系统分享。
- 从本地 JSON 文件导入，导入前进行完整性校验。
- 导入失败时恢复原有数据。
- 支持清空全部任务和专注记录，并提供双重确认。
- 数据默认保存在本地，无需登录。

### 当前限制

- 费曼讲解目前仅支持文字版，录音功能暂未提供。
- 白噪音播放器和音频素材尚未提供，设置页会显示“即将推出”。
- 正式应用商店发布前仍需配置 Android/iOS 正式签名。
- 产品截图正在整理，README 暂不使用占位图片。

## 技术栈

| 层级 | 技术 | 用途 |
|---|---|---|
| 客户端 | Flutter 3.47.2 / Dart 3.13.2 | 跨平台界面与业务逻辑 |
| 状态管理 | flutter_riverpod | 响应式状态管理 |
| 本地存储 | Hive、SharedPreferences | 任务、专注记录和设置持久化 |
| 图表 | fl_chart | 趋势图和学科占比 |
| 路由 | go_router | 声明式路由 |
| 通知 | flutter_local_notifications | 会话完成通知 |
| 数据交换 | file_picker、share_plus | 备份导入与分享 |
| 图标 | Material Icons | Flutter 内置图标 |

## 环境要求

- Flutter 3.47.2 或与 `pubspec.yaml` 兼容的稳定版本。
- Dart SDK `>=3.11.4 <4.0.0`。
- Android 构建需要 Android SDK、NDK 和 Java 17。

## 安装和运行

```bash
git clone https://github.com/yexinsky/qingzhou.git
cd qingzhou
flutter pub get
flutter run
```

## 质量验证

提交前建议执行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build web
flutter build apk --debug
```

截至 2026 年 9 月 6 日，当前版本已完成以下验证：

- `flutter analyze`：无问题。
- `flutter test --coverage`：42 项测试全部通过（含灵活计时和费曼数据模型覆盖）。
- `flutter build web`：通过。
- `flutter build apk --debug`：通过。
- Debug APK 已在 `127.0.0.1:5557` 和 `127.0.0.1:16416` 两个 Android 模拟器安装并完成冷启动和各 300 次随机稳定性测试，无崩溃。

GitHub Actions 位于 `.github/workflows/flutter-ci.yml`，会自动执行格式检查、静态分析、测试以及 Web、Android Debug 构建。

## 项目结构

```text
lib/
├── core/
│   ├── services/       # 通知、震动和数据备份
│   ├── theme/          # 主题与颜色
│   └── utils/          # 通用工具
├── data/
│   ├── models/         # Hive 数据模型
│   └── repositories/   # 本地数据仓库
├── providers/          # Riverpod 状态管理
├── router/             # 应用路由
└── views/
    ├── focus/          # 固定与灵活专注计时
    ├── feynman/        # 费曼学习、文字讲解、复盘和卡点热力图
    ├── plan/           # 多日任务规划
    ├── stats/          # 日、周、月统计
    ├── college/        # 院校排名查询（软科）
    ├── history/        # 专注历史
    └── settings/       # 设置与数据管理

assets/data/            # 内置院校排名数据（tool/fetch_bcur.dart 生成）
tool/                   # 开发期数据抓取脚本
test/                   # 单元测试与 Widget 测试
.github/workflows/       # 持续集成
```

## 版本与数据兼容

- 应用版本以 `pubspec.yaml` 为唯一来源，设置页会在运行时读取版本号。
- Task 和 FocusSession 的 Hive 字段采用追加方式演进，现有本地数据可继续读取。
- 费曼学习单元与卡壳记录使用独立 Hive 数据盒。
- JSON 备份格式已升级为 v2，并继续兼容 v1 备份导入。
- 建议在升级或测试导入功能前先导出 JSON 备份。

## 参与开发

提交应保持范围清晰，并采用 Conventional Commits 风格，例如：

```text
feat: improve focus workflow and planning
fix: correct background timer recovery
 test: add timer and repository coverage
 docs: update setup and verification guide
```

Pull Request 在合并前应通过仓库中的 Flutter CI。

## AI 辅助声明

本项目使用 AI 工具辅助代码实现、测试和文档整理，最终变更由项目维护者审查和发布。

## License

本项目采用 MIT License，详见 [LICENSE](LICENSE)。
