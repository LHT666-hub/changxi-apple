# 常曦 UI / Visual Change Log

此文件记录 ChatGPT 参与的 UI 改造，避免设计决策只存在于对话中。

---

## 2026-09-21 · Phase A：Moon System / UI 2.0

### 月相本体
- Commit: `8a5354543bba79e78c09055d39b497c5baf6c842`
- 重做首页“今日月相”和月相详情视觉。
- 加入球体光影、月面纹理、光晕和轨道。

### 首页大月池
- Commit: `a4faab29a2975a15ac63822b3ac7008e6a0418e0`
- MoonPool 从“角色 + 椭圆水盘”改为悬浮月体、轨道、月池倒影和弱水波。
- 保留 listening / thinking / responding / success / doctorReply / quietAlert 等业务状态。

### App 内启动体验
- Commit: `9b4e5624be7ca0950de8fdcf04ff64559efbe7b6`
- 新增月亮亮起、光圈展开、“常曦”与品牌文案淡入。
- UI testing 自动跳过启动动画。

### First-run onboarding
- Commit: `ec78b7710d04819f630a97a8298bad8f018f3a5b`
- 单页欢迎改为 5 段式 onboarding：
  1. 欢迎
  2. AI 健康陪伴
  3. 家庭 / 家医连接
  4. 隐私
  5. 个性化设置

### 首页层级
- Commit: `20e6deb59f29d1c5fdc02938836f345155463cb6`
- 重排首页主视觉、AI 入口、常用动作、今日摘要和月相卡片。
- 首页各处月亮开始统一使用 MoonDisc。

### 稳定性与视觉基建
- Commits:
  - `b3b016987980e71a64d0b5fb7ce4c5b5931181fc`
  - `f398cf70d436da5c316314672ffb39684761d6b0`
  - `da8b5105b02b1bc890526dbe0aff22a138d94a24`
  - `0cddf2b3bd79c1a59cc3ad9d61c523fbdeb2e5e2`
- 调整启动任务隔离、MoonPool Canvas 路径、共享卡片/按钮/加载/空状态，并清理废弃 helper。

---

## 2026-09-21 · Phase B：Visual System V3

设计目标：从“医疗蓝 + 多玻璃 + serif 分散使用”收敛为 **Lunar Quiet / 月白健康**。

### V3 Token 基础
- Commit: `19e0711ced420116374d08140e3e53adba5260c7`
- 新增语义色：
  - canvas / surface / raisedSurface
  - actionPrimary / actionPrimarySoft
  - brandMoonlight / brandIvory
  - statusPositive / Warning / Critical
- 新增：
  - CXTypography
  - CXSpacing
  - CXRadius
  - LunarGlyph
- 保留旧 CX.blue / teal / coral / gold 兼容映射。

### 月白背景
- Commit: `5921814b9b6e309ea95f560077540cf04df1d493`
- MoonBackground 从整屏蓝色 Mesh 转为月白画布。
- 冷蓝光仅保留为弱氛围。
- MoonGarden 背景插画显著降低透明度。

### 首页迁移
- Commit: `03f6d59d63eaa924ed4b7a05daf91a194280be89`
- 首页迁移到 CXTypography / CXSpacing。
- Header 使用 LunarGlyph。
- 常用功能和月相卡片退出 Glass，改为平面 Surface。
- 状态色开始迁移到 semantic tokens。

### Launch + Onboarding 迁移
- Commit: `1a13225bbe1345db20256d39f8eb2192dadbef3e`
- 启动页品牌标题退出 serif。
- Onboarding 主标题退出 serif。
- Header 使用 LunarGlyph。
- 部分间距与圆角迁移到 V3 Token。

---

## 下一步

1. 全仓库逐步清理 `.fontDesign(.serif)`。
2. Health / Services / Chat / Profile 迁移 CXTypography。
3. CX.blue 逐步替换为更明确的语义 Token。
4. 限制 Glass 到导航和控制层。
5. 继续用 LunarGlyph / 月弧 / 光点 / 倒影构建统一平面图形语言。
6. 增加真实 Xcode 构建与截图 QA 记录（需要可运行的 Xcode 环境）。
