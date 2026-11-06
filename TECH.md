# 弦上知音 · 技术架构文档

> 版本：1.0.0+1 ｜ Flutter 3.47.7 / Dart 3.13.5 ｜ 目标平台：macOS 桌面（已兼容移动）

---

## 一、技术栈总览

| 类别 | 选型 | 用途 |
|---|---|---|
| 框架 | Flutter 3.47 / Dart 3.13 | 全 UI 与业务 |
| 本地数据库 | sqflite 2.4 + path | 收藏、练习分数、进度 |
| 音频播放 | audioplayers 6.5 | 110+ 本地 m4a/mp3 资源 |
| 音频采集 | record 6.2 | 麦克风 PCM 流（智能辅助） |
| 矢量图 | flutter_svg 2.3 | 减字谱、指法手势 SVG |
| 图片选择 | image_picker | 个人练习录音上传 |
| 渲染 | CustomPainter + dart:ui | 3D 古琴、数字琴境、水墨底纹 |

**零后端、零网络**：所有资源（110 个音频、30+ 张图片、SVG 谱）全部打进 assets，离线可用。

---

## 二、目录结构

```
lib/
├── main.dart / app.dart              入口
├── theme/app_theme.dart              全局主题（宣纸色板、字体、卡片样式）
├── common/                           公共组件
│   ├── ink_scaffold.dart             水墨底纹 Scaffold（全应用统一背景）
│   ├── ink_landscape.dart            程序化水墨山水 Painter
│   ├── guqin_sound.dart              合成琴音播放封装
│   ├── pitch.dart                    YIN 音高检测
│   └── widgets.dart                   PaperCard / SectionTitle / TagChip 等
├── data/                            数据层
│   ├── app_database.dart             sqflite 建表与 CRUD
│   ├── models.dart                   琴曲/笔记/成绩/印章 模型
│   ├── seed_data.dart                 内置 11 首琴曲、8 篇文化文章
│   └── practice_data.dart / scores   练习记录与评分
└── features/
    ├── home/                         首页 Tab（轮播、底部导航）
    ├── learn/                        习琴 Tab（指法、减字谱、琴曲）
    ├── experience/                    体验 Tab（数字琴境、意境生音、3D）
    ├── profile/                      我的（印章、收藏、设置）
    ├── assist/                       智能演奏辅助（实时音高反馈）
    ├── culture/                      文化资料库（每日琴签、冷知识）
    ├── fingering/                    指法示范
    ├── notation/                     减字谱拼字对战
    ├── model3d/                      3D 古琴（Canvas 投影）
    ├── realm/                        数字琴境（沉浸式交互）
    ├── visualize/                    听辨可视化
    └── pieces/                       琴曲列表与详情
```

---

## 三、核心功能模块

### 1. 首页（home_page.dart）
- 顶部 Hero 轮播：`PageView` + 12 张水墨图（qin_hero_mist / ink_* / qin_hero_guqin），`BoxFit.cover`
- 底部导航：`RootScaffold` 用 `IndexedStack` 常驻 4 个 Tab，切到"我的"时调 `ProfilePage.reload()` 刷新印章
- 主题色板：`AppColors.paper = 0xFFF4EDE0`（宣纸）、`cinnabar = 0xFFB03A2E`（朱砂）、`jade = 0xFF4A7C59`（石绿）

### 2. 水墨统一背景（ink_scaffold.dart）
- `InkScaffold`：除首页外所有页面的骨架，Stack 三层：
  1. 底层 `Image.asset(backdropImage)`：每页配专属水墨图（意境生音用 `ink_waterfall_autumn.jpg`、指法用 `ink_bamboo_pavilion.jpg` 等）
  2. 中层宣纸渐变罩（80–84% 不透明），保证文字可读
  3. 顶层 `InkBackdropPainter`：程序化淡月、云气、三重远山、"高山流水"题字水印，随滚动视差
- `PaperCard` 面板半透明（86% 纸白），山水能透出来

### 3. 数字琴境（realm_page.dart）
- 三种场景：山林（松风）、书斋（檐雨）、月夜（夜虫），各配 `realm_forest/study/night.jpg` 底图
- `RealmPainter` 自绘七弦琴：深褐漆色渐变（#3A2418→#120A06）、牛毛断纹暗线、漆面反光高光
- 交互：`Listener` 监听 `PointerDown/Move/Up`，命中检测 `_stringHit` 把 y 坐标映射到 7 根弦（弦在屏高 0.665、间距 0.034）；右半屏拨弦、左半屏按弦
- 拨弦动画：`_pluckAge` 每帧推进，弦做正弦衰减偏移
- 环境音：`_ambience` AudioPlayer 循环播放，默认音量 0.12

### 4. 意境生音（mood_sound_page.dart）
- 6 个意境：清幽/苍茫/明朗/沉静/萧瑟/热烈，各配 notes 列表与主题色
- 声景画布：`_SoundCanvas` StatefulWidget，点画布添加墨滴涟漪，**不使用 Ticker/定时器**（避免触发 mouse_tracker 断言），只在播音时 setState 重绘
- 随机一曲按钮、AI 诗词关键词、用户点画布即兴加一音

### 5. 智能演奏辅助（assist_page.dart + practice_engine.dart + pitch.dart）
- 麦克风 `record` 插件采 PCM 16kHz 单声道
- YIN 算法实时估基频：`pitch.dart` 起奏阈值 0.004
- **八度吸附**：古琴二次谐波强，YIN 常把弦音认高八度，`_octaveSnap()` 把音差折到 ±600 音分内再打分
- 实时反馈：当前音高、偏差音分、命中/偏离

### 6. 指法示范（fingering_page.dart）
- SVG 手势图（hand_left_press.svg / hand_right_pluck.svg）
- `_paintFinger` 指身高光、`_drawHand` 手投影（触弦点椭圆软影）

### 7. 减字谱拼字对战（notation_page.dart）
- `flutter_svg` 渲染减字谱（大九勾一、食七挑二等 60 秒竞速）
- 60 秒倒计时、对错计数

### 8. 3D 古琴（model_page.dart）
- 自绘 3D 投影：把古琴三维顶点（V3 类）绕 yaw/pitch 旋转，透视投影到 Canvas
- 手势：`onScaleStart/Update` 双指缩放、单指拖动旋转、点弦即拨

### 9. 文化资料库（culture_list_page.dart + daily_card.dart）
- 每日琴签：14 句轮播 + 朱砂印打卡（存 sqflite）
- 古琴冷知识胶囊：10 条
- 8 篇文化长文（历史/形制/琴派/工艺/琴道）

### 10. 我的（profile_page.dart）
- 9 枚成就印章：四色（朱砂/泥金/石青/松烟），解锁带投影
- 静态 `reload()` 方法供 RootScaffold 在切到 Tab 3 时调用（IndexedStack 不自动重建）

### 11. 琴曲库（piece_list / piece_detail）
- 11 首琴曲：流水、梅花三弄、平沙落雁、阳关三叠、醉渔唱晚、孔子读易、酒狂、搔首问天、培兰、秋风吹、神人畅
- 详情含背景典故、谱面、配套学习三个 Tab

---

## 四、音频资源

```
assets/audio/
├── 11 首完整琴曲 mp3（流水、梅花、平沙、阳关等）
└── sfx/  109 个音效 m4a
    ├── amb_forest.m4a / amb_night.m4a / amb_study.m4a  环境音
    ├── bai_0..6.m4a       散音 7 根弦
    ├── an_0..6.m4a        按音 7 根弦
    ├── fan_0..6.m4a       泛音 7 根弦
    ├── chuo_0..6.m4a      绰（上滑）
    ├── zhu_0..6.m4a       注（下滑）
    ├── da/tiao/ti/pi/...  指法
    └── click.m4a          UI 反馈
```

---

## 五、踩坑记录（关键决策）

1. **mouse_tracker 断言刷屏**：桌面端高频 `Timer.periodic` 调 `setState` 会和鼠标事件派发撞车，触发 `!_debugDuringDeviceUpdate`。最终方案：彻底删除动画引擎，只在数据变化时重绘。
2. **YIN 八度误判**：古琴低音弦二次谐波强，必须加八度吸附，否则智能辅助永远 0 分。
3. **IndexedStack 不刷新**：底部导航常驻 Tab，切回时不重新 initState，需要静态 `reload()` 主动刷新。
4. **资源热重启不打包**：新增 assets 图片必须 `q` 退出 `flutter run` 重跑，R 热重启不会重新 bundle。

---

## 六、未来可扩展

- 接入云同步练习记录
- 减字谱识别（拍照识别）
- 多人琴房（WebSocket）
- AR 桌面古琴
