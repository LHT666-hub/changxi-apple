# 疼痛记录深化依据 · 2026-09-08

## 资料与落地边界

- VA/DoD 2022 疼痛评估条目包含起始、部位、持续、加重／缓解因素、放射位置、规律和性质。本项目仅借用这些描述维度，不使用指南中的阿片治疗建议，不提供治疗推荐。https://healthquality.va.gov/HEALTHQUALITY/guidelines/Pain/cot/VADoDOpioidsCPGProviderSummary.pdf
- VA 疼痛工具目录将活动、睡眠等影响纳入评估。本项目补充本人描述的活动／睡眠影响，但没有复制量表或声称自制选项是经过验证的 DVPRS、PEG 等量表。https://www.va.gov/PAINMANAGEMENT/Research/Tools-Assessment-Recruitment.asp
- NHS 头痛说明中的突然极剧烈头痛、言语困难、肢体无力等用于“先求助”信息，不构成完整分诊规则。https://www.nhs.uk/symptoms/headaches/
- 中国急救号码和高危胸痛说明以国家卫健委资料为依据。https://www.nhc.gov.cn/xcs/c100122/202411/81a60171b43d43ff98cc6110d65a4136.shtml

设计推导：本人表达优先，家属协助转述单独标明；未选择和“说不清”不能转换为零分；数字强度需要明确操作确认；描述牵扯部位不推断神经走向或脏器来源；语音候选位置必须由本人确认。以上是产品设计选择，不是经过验证的临床工具。

## 三维模型与定位

来源：MakeHuman 官方基础网格，官方明确基础网格采用 CC0 1.0。下载时官方 master SHA：a8bc2d54ff0ac92e78ff71431b1023eda42bf482。

- 网格：https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/3dobjs/base.obj
- 许可：https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/LICENSE.md
- 原始许可副本：Resources/PainModels/MAKEHUMAN-LICENSE.txt。

加工只保留 `body` 面组，排除 helper 和 joint 几何，将四边形三角化、身高归一化到 2、计算平滑法线。输出 13,380 顶点／26,756 三角形。该模型是通用美术人体表面，不是患者扫描，也未经医学级解剖校验；现阶段不包含骨骼、肌肉、内脏层级。

原生 SceneKit 负责渲染和表面命中；记录保存模型局部三维坐标和版本。标记挂在同一模型节点下，旋转时随表面运动，不用屏幕坐标伪装三维定位。二维插画坐标与三维坐标分开保存，不做未经校准的自动映射。

当前三维支持点标记、沿表面划线和圈选表面片区，并提供头面、肩颈、胸腹、背腰、上肢和下肢的常用表面部位名称。六大部位仍是同一人体上的不同相机取景，不代表六套临床解剖模型。左右是本人身体左右，模型取景不可用于判断病灶深度、神经走向或内脏来源。

## 验收状态

已做网格面索引、三角形数量、归一化与资源存在性检查。模块入口已接入健康页；未在此 Windows 环境运行 iOS 构建或实际验收相机、触摸命中、语音权限和渲染效果，也未推送触发长时间 CI。合入另一台电脑代码前需一次 Mac 原生验收，尤其检查正背方向、左右侧、缩放、圈线手势与历史标记位置。
