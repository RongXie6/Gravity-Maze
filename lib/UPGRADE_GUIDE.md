# Labirinto 升级指南 v2.0

## 📁 文件结构

```
lib/
├── main.dart                    ← ✅ 已升级：启动画面 + 自动登录路由
├── service/
│   └── auth_service.dart        ← 🆕 登录/注册/用户数据服务
├── view/
│   ├── auth_view.dart           ← 🆕 精美登录/注册页面
│   ├── level_select_view.dart   ← ✅ 已升级：用户面板、锁定逻辑、成就展示
│   └── maze_view.dart           ← ✅ 已升级：粒子爆炸、毛玻璃HUD、进场动画
├── controller/
│   └── game_controller.dart     ← ✅ 已升级：成就触发、时间统计
├── model/
│   ├── game_model.dart          ← 无变化
│   └── level_data.dart          ← 无变化
└── physics/
    └── ball_physics.dart        ← 无变化
```

---

## 🚀 快速集成步骤

### 1. 更新 pubspec.yaml
```bash
flutter pub get
```
唯一新增的硬性依赖是 **`crypto: ^3.0.3`**（用于密码哈希）。

### 2. 建立目录结构
```bash
mkdir -p lib/service lib/view lib/controller lib/model lib/physics
```

### 3. 文件放置
| 提供的文件 | 放置路径 |
|-----------|---------|
| `auth_service.dart` | `lib/service/auth_service.dart` |
| `auth_view.dart` | `lib/view/auth_view.dart` |
| `level_select_view.dart` | `lib/view/level_select_view.dart` |
| `maze_view.dart` | `lib/view/maze_view.dart` |
| `game_controller.dart` | `lib/controller/game_controller.dart` |
| `main.dart` | `lib/main.dart` |

保持不变（原始文件直接使用）：
- `lib/model/game_model.dart`
- `lib/model/level_data.dart`
- `lib/physics/ball_physics.dart`

### 4. 修复导入路径
各文件顶部的 import 需根据你的实际目录结构调整。例如在 `maze_view.dart` 中：
```dart
// 改为你项目中实际的路径
import '../controller/game_controller.dart';
import '../model/game_model.dart';
import '../model/level_data.dart';
import '../service/auth_service.dart';
```

---

## ✨ 新增功能概览

### 🔐 登录/注册系统
- 用户名 + 邮箱 + 密码注册
- SHA-256 密码哈希，本地安全存储
- 自动记住登录状态（下次打开直接进入主界面）
- 游客模式（跳过注册直接玩）
- 退出登录功能

### 👤 用户档案
- 用户名、称号（新手/初学者/探险家/迷宫大师）
- 总星数、完成场次统计
- 成就系统（满星奖励徽章）

### 🎨 UI 视觉升级
- **启动画面**：品牌动画 + 加载指示
- **登录页**：渐变背景、毛玻璃卡片、平滑切换动画
- **主界面**：用户信息横幅、关卡解锁逻辑（前一关至少1星才解锁）
- **关卡卡片**：解锁/锁定状态差异化显示，带图标标签（计时器/陷阱）
- **游戏内HUD**：毛玻璃效果（BackdropFilter blur）

### 🎮 游戏体验
- **进场动画**：棋盘弹出式缩放入场（easeOutBack）
- **胜利特效**：60 个彩色粒子爆炸 + 金色光晕闪烁
- **失败特效**：红色画面闪烁
- **HUD 升级**：毛玻璃背景 + 计时器颜色根据剩余时间变色（<10秒变红）
- **振动反馈**：胜利/失败/旋转操作触觉反馈

### 🎯 游戏画面升级
- 球体：4 色渐变 + 镜面高光 + 外发光
- 墙壁：双层渐变 + 投影阴影
- 星星：金色外发光
- 目标点：红色外发光 + 径向渐变
- 陷阱：深色阴影 + 双边框

---

## 🔧 可选扩展

### 添加音效
1. 在 `pubspec.yaml` 取消注释 `audioplayers`
2. 在 `game_controller.dart` 中 `onStarCollected` 和 `onHoleFall` 回调内播放音效：
```dart
controller.onStarCollected = () => _audioPlayer.play(AssetSource('sounds/star.mp3'));
controller.onHoleFall = () => _audioPlayer.play(AssetSource('sounds/fall.mp3'));
```

### 添加更多关卡
在 `level_data.dart` 的 `levels` 列表末尾追加：
```dart
LevelData(
  number: 7,
  hasHoles: true,
  hasTimer: true,
  squareBoard: true,
  controlMode: ControlMode.flip,
  timeLimit: 30,
),
```

### 更改迷宫大小
在 `level_select_view.dart` 的 `_openLevel` 方法中：
```dart
final model = GameModel(cols: 7, rows: 9); // 更大的迷宫
```
