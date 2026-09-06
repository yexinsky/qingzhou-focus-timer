# 轻舟 - 沉浸式学习专注器

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-blue" alt="Flutter">
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-green" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

> 面向考研及长期备考用户的本地优先学习专注工具，覆盖计划、专注、统计和复盘。

## 功能

### 可靠专注计时

- 25、45、60、90 分钟快捷计时。
- 开始、暂停、恢复、重置与放弃。
- 按真实结束时间校正后台和锁屏期间的倒计时。
- 保存进行中的会话，应用重新启动后可恢复。
- 支持短休息、长休息和下一轮专注。
- 严苛模式会在放弃专注前进行二次确认。
- 计时结束支持本地通知和震动反馈。

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

### 数据管理

- 导出版本化 JSON 备份并通过系统分享。
- 从本地 JSON 文件导入，导入前进行完整性校验。
- 导入失败时恢复原有数据。
- 支持清空全部任务和专注记录，并提供双重确认。
- 数据默认保存在本地，无需登录。

### 当前限制

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
- `flutter test --coverage`：36 项测试全部通过。
- `flutter build web`：通过。
- `flutter build apk --debug`：通过。
- Debug APK 已在 `127.0.0.1:5557` 和 `127.0.0.1:16416` 两个 Android 模拟器安装并完成冷启动、页面导航、新建任务和随机稳定性测试。

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
    ├── focus/          # 专注计时
    ├── plan/           # 多日任务规划
    ├── stats/          # 日、周、月统计
    ├── history/        # 专注历史
    └── settings/       # 设置与数据管理

test/                   # 单元测试与 Widget 测试
.github/workflows/       # 持续集成
```

## 版本与数据兼容

- 应用版本以 `pubspec.yaml` 为唯一来源，设置页会在运行时读取版本号。
- Task 的 Hive 字段采用追加方式演进，现有本地数据可继续读取。
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
