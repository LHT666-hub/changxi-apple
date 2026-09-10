# 常曦局部解剖模型管线

正式资产使用 Blender 处理，不在 App 运行时裁切完整人体。目标输出按 `头部 / 肩颈 / 胸腹 / 背腰 / 左右手臂 / 左右腿脚` 分包，并在每包中保留 `体表 / 肌肉 / 骨骼` 三个可独立显示的节点。

生产路径使用 [Human-Atlas](https://github.com/slorksmo/Human-Atlas)
打包的 BodyParts3D 统一坐标数据。`export_human_atlas.py` 对体表、肌肉和
骨骼应用同一个局部裁切体积，合并每一层，并面向 iPhone 做降面导出。
早期 Z-Anatomy 管线保留为备用和可重现参考，但不能再与另一个人体的
体表网格混合，否则会造成尺寸和解剖位置错位。

源模型为 BodyParts3D，并由 Human-Atlas 完成移动端预优化。它适合做医学位置沟通，但不是诊断工具。原始大文件不提交；仓库只提交可重复的导出脚本、轻量输出和署名。

## 约束

- 所有结构保留原始标准名称和左右侧信息。
- 每个局部包控制三角面和纹理大小，模型边界在 Blender 中封口，不在客户端生硬切割。
- 体表标记只表达患者感受到的位置；切换肌肉或骨骼层不等于推断疼痛来源。
- 派生模型按 CC BY 4.0 分发，并在 App 与仓库中保留 Human-Atlas、BodyParts3D 署名。

## 导出正式资产

```sh
CHANGXI_ATLAS_DIR=/path/to/Human-Atlas/public/models \
CHANGXI_ANATOMY_OUT=/tmp/changxi-anatomy \
blender --background --factory-startup --python Tools/AnatomyPipeline/export_human_atlas.py
```

## 检查源文件

```sh
blender --background /path/to/Startup.blend --python Tools/AnatomyPipeline/inspect_z_anatomy.py
```
