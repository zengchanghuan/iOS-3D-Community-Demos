# 性能实测报告 · 2026-10-19

所有图表来自本仓库运行产生的原始数据。**当前没有真机稳定 60 FPS 或 ASTC 降低整机内存 75% 的实测结论。** 下列数据属于 iOS Simulator / Debug，用于验证实现和实验方法，不能外推为线上性能。

## 环境与可追溯性

| 项目 | 本次条件 |
|---|---|
| Xcode / Instruments | 27.1（27A9275） |
| 目标 | iPhone 18 Pro 模拟器，iOS 27.0 |
| 构建 | Debug，未连接 Xcode 源码调试器；FPS 使用 XCTest 驱动输入 |
| FPS 批次 | 2026-10-19 14:50，Asia/Shanghai |
| 内存批次 | 2026-10-19 14:53–14:54，Asia/Shanghai，单次 40 秒录制 |
| 资源 | 滚动：3 张轻量模型卡片；旋转：Fox；内存：SCNSphere + SCNView Controller |
| 限制 | 未控制宿主机其他任务、真机热状态和低电量模式；只做单次探索采样，不报告统计显著性 |

## Demo 1：滚动与模型交互的连续帧时间

使用 `--capture-fps` 记录每个 CADisplayLink 回调 timestamp。UI 测试在广场上下滚动 5 组，再在模型详情横向拖动 6 次。原始记录覆盖页面停留期间，因此包含加载/截图/测试调度，**不是严格逐帧标注的“仅手指移动区间”**。未裁剪最慢帧、未平滑、未删除预热区间；短暂返回广场的第二段记录保留，但统计使用较长的主段。

| 场景 | 窗口 | 间隔数 | 平均回调 FPS | P50 / P95 间隔 | 最大间隔 | >20 ms 比例 |
|---|---:|---:|---:|---:|---:|---:|
| 模型广场滚动 | 15.38 s | 876 | **56.94** | 16.67 / 16.67 ms | 307.21 ms | 1.60% |
| Fox 模型旋转 | 8.49 s | 494 | **58.17** | 16.67 / 16.67 ms | 85.07 ms | 1.82% |

平均值按 `间隔数 / 总时长` 计算，不是对每帧 `1/delta` 做算术平均。P95 接近 16.67 ms 说明大部分回调处于 60 Hz 节奏，但最大间隔和均值明确否定“全程稳定 60”的强断言。这里无法仅靠 timestamp 区分 UI 工作、测试注入、宿主机调度和 GPU 负载，不能直接把长帧归因于渲染器。

![实际回调间隔曲线](Benchmarks/fps-timeline.png)

[滑动操作后的实际页面截图](Screenshots/Gallery-Scroll.png)与[旋转后的截图](Screenshots/SceneKit-Interaction.png)来自后续 UI 回归批次，用于展示运行场景，不与 14:50 原始采样逐帧对应。截图上的 FPS 是当时的 1 秒窗口，不是整个批次统计。

原始数据：

- [广场主段 timestamps](Benchmarks/fps-library-3143346A-A58F-4DA3-BE3C-5AAB448C9790.json)
- [模型 timestamps](Benchmarks/fps-model-5D0C84D7-3F22-49B7-9670-9BAEF7D681EA.json)
- [返回广场短段](Benchmarks/fps-library-47A59F7A-C0E5-4764-819F-0DA3E8D940D8.json)
- [机器可读统计](Benchmarks/fps-summary.json)，[计算/绘图脚本](../Scripts/plot-fps.py)

复算：在 Python 环境安装 `numpy matplotlib` 后运行 `python Scripts/plot-fps.py`。脚本按场景选择样本数最多的主段；如追加新实验应放入独立批次目录，避免把新旧数据混成一组。

## Demo 2：ASTC 仍需真机验收

| 指标 | PNG → RGBA8 | ASTC 4×4 | 证据等级 |
|---|---:|---:|---|
| 1024²、单 mip payload | 4 MiB | 1 MiB | 格式计算，不是 Instruments 数据 |
| 模拟器渲染 | 已显示 | 设备报告不支持，明确提示 | UI 回归 |
| Metal device allocation | API 返回 0，标为不可用 | 未测 | 不可用于收益判断 |
| 真机纹理 allocation / footprint | 待测 | 待测 | 不填虚构数字 |

理论 payload 降低 75%，不代表 App footprint 下降 75%，更不代表 OOM 已解决。对照实现和格式控制详见 [Demo 2 技术文章](DEMO2.md)，真机录制步骤见 [实验规程](EXPERIMENTS.md)。

## Demo 3：真实 Instruments 内存下降曲线

下图直接截取 Instruments Allocations 的 `Current Bytes / All Heap & Anonymous VM`，不是根据对象数画出的假内存曲线。图中先逐步增长，解除引用环后下降，weak 阶段仍存在系统/图形分配与缓存增长；没有把后半段裁掉来制造“完全回到基线”的印象。

![Instruments 真实分配曲线及统计](Screenshots/Instruments-Allocations.png)

[阶段日志](Benchmarks/memory-events.json)来自同一 App 运行，时间零点为 benchmark Controller 创建；Instruments 时间零点为开始录制，两者存在启动偏移，不能直接当作相同横坐标。

| 阶段 | App 相对时间 | 存活实验 Controller | 结果 |
|---|---:|---:|---|
| 基线 | 0.006 s | 0 | 开始 |
| 强引用环 10 次后 | 11.764 s | 10 | 页面移除后仍保留 |
| 解除前 | 16.851 s | 10 | 保留平台 |
| 解除后 | 16.911 s | 0 | 引用环释放 |
| weak 对照 10 次后 | 30.753 s | 0 | 无同类对象累积 |

全录制区间的 Instruments 表格读数：

| 分配分类 | 结束时 Persistent bytes | 全程 Total bytes（累计分配） |
|---|---:|---:|
| All Heap & Anonymous VM | **24.83 MiB** | 153.25 MiB |
| All Heap Allocations | 4.85 MiB | 102.98 MiB |
| All Anonymous VM | 19.98 MiB | 50.27 MiB |

**Total bytes 是累计分配，不是峰值；153.25−24.83 不能算作“修复节省内存”。** 当前截图可以证明曲线有下降，阶段日志可以证明 10→0 的对象释放；尚未导出释放点两侧的精确 Current Bytes 数值，因此不编造下降 MiB 或百分比。它也不是 VM Tracker 的 resident size/进程 footprint，更不是 GPU texture allocation。VM Tracker 在本次模拟器 trace 中没有可用曲线。

可审查原件：[完整 Allocations trace ZIP](Benchmarks/allocations.trace.zip)（约 10 MiB）。解压后用 Instruments 打开 `community3d-memory-verified.trace`。SHA256：`8ee3f0674f32932f6e84bd920731c990269ca965fe80a37cba2da613f47d403d`。该文件包含本地实验进程路径/机器元数据；对外公开前可按项目需求另存脱敏报告。

第一次用 `.app` 文件路径 launch 的 trace 没有形成有效的实验阶段证据，未纳入本报告；最终使用已安装 bundle ID 重新录制，并核对了完整阶段日志。

## 复现 Instruments 录制

先构建并安装到模拟器，然后：

```sh
xcrun xctrace record --template Allocations \
  --device YOUR_SIMULATOR_UDID --time-limit 40s \
  --output /tmp/community3d-memory.trace \
  --launch -- dev.community3d.demos --memory-benchmark
```

`YOUR_SIMULATOR_UDID` 取自 `xcrun simctl list devices available`。结果路径必须不存在。App Documents 下 `memory-events.json` 记录阶段；若没有该文件或缺少 finished，不应把录制视为有效对照。

## 还缺哪些证据？

真机 Release 的多轮采样、滚动手势区间精确标记、Time Profiler 对最慢帧的归因、ASTC GPU Capture 与纹理实际分配、真实进程 footprint、Android 对照。现有材料证明功能和实验可复现，不宣称完成线上性能治理。
