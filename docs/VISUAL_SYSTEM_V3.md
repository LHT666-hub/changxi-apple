# 常曦 Visual System V3

更新时间：2026-09-21

## 目标

常曦的视觉方向从“医疗蓝 + 多层玻璃 + 分散的月亮装饰”收敛为：

**Lunar Quiet / 月白健康**

关键词：

- 月白画布
- 深墨文字
- 克制活力蓝
- 极少量暖月金
- 系统字体优先
- 内容层平面清晰
- 导航与控制层才使用 Glass
- 圆月 / 弦月 / 轨道弧线 / 水平倒影构成统一图形语言

## 1. Typography

UI 不再把 serif 作为默认品牌手段。

核心层级：

| Token | SwiftUI | 用途 |
| --- | --- | --- |
| CXTypography.brandTitle | 31pt Semibold | 启动页“常曦”字标过渡态 |
| CXTypography.display | largeTitle Semibold | 每屏唯一主标题 |
| CXTypography.title | title2 Semibold | 大区块标题 |
| CXTypography.section | headline Semibold | 卡片/栏目标题 |
| CXTypography.body | body | 正文 |
| CXTypography.supporting | subheadline | 辅助说明 |
| CXTypography.meta | footnote | 元信息 |
| CXTypography.micro | caption | 极小标签 |
| CXTypography.numeric | title Rounded Semibold | 健康数值 |

规则：

1. 一屏最多一个 display。
2. 健康数值配合 monospacedDigit()。
3. serif 不再作为业务界面的默认标题风格。
4. “常曦”品牌感主要依赖字标、留白、图形和色彩，不依赖大面积衬线字体。

## 2. Color

主要语义 Token：

| Token | Light | 用途 |
| --- | --- | --- |
| canvas | #F7F6F2 | 全局月白背景 |
| surface | #FCFCFA | 内容卡片 |
| raisedSurface | #FFFFFF | 提升层级 |
| actionPrimary | #3568C8 | 主要交互 |
| actionPrimarySoft | #DCE8FA | 弱交互背景 |
| brandMoonlight | #B7CAE2 | 月光、轨道、氛围 |
| brandIvory | #E8DCC0 | 极少量暖月色 |
| statusPositive | #2F806F | 完成 / 正常 |
| statusWarning | #B7833B | 注意 |
| statusCritical | #C05D5D | 风险 / 异常 |

旧 CX.blue / moonlight / teal / coral / gold 暂时保留兼容映射，后续逐页迁移为语义名称。

## 3. Grid & Spacing

基础节奏：4pt 微单位 + 8pt 主节奏。

CXSpacing：

- micro 4
- xs 8
- sm 12
- md 16
- lg 20
- xl 24
- section 32
- hero 40
- page 20

页面左右边距默认 20pt；内容最大宽度维持约 680–720pt。

## 4. Radius

仅保留四档：

- CXRadius.sm = 12
- CXRadius.md = 18
- CXRadius.lg = 24
- Capsule

避免页面中出现大量 14 / 19 / 21 / 22 等临时圆角。

## 5. Surfaces

- 内容卡：solid surface + 极弱边框 + 极弱阴影。
- Glass：仅优先用于 Tab Bar、悬浮按钮、导航控制、临时控制层。
- 主操作按钮：统一 actionPrimary，不用强烈三段渐变制造质感。
- 页面背景：以月白为主，冷蓝只作为 Hero 区域的氛围光。

## 6. Graphic Language

统一采用四个母题：

1. 圆月
2. 弦月 / 轨道弧线
3. 光点 / 节点
4. 水平倒影 / 时间线

新增 LunarGlyph 作为第一枚品牌平面图形组件。

工具性图标继续优先使用 SF Symbols。

## 7. Migration Strategy

不一次性删除旧 Token。

迁移顺序：

1. DesignSystem V3 Token
2. Home
3. Launch + Onboarding
4. Health
5. Services
6. Chat
7. Profile
8. Shiyang / Constitution / Pain
9. 清理旧 CX.blue 等兼容别名
10. 统一空状态、加载态和插画资产

## 8. Safety

本轮视觉升级不应修改：

- 玄同 API 协议
- Auth
- Health Sync
- 本地数据模型
- 家医服务状态机
- 权限业务逻辑

视觉变更与业务逻辑保持解耦。
