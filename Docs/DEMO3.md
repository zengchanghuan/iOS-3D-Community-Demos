# Demo 3 · 从“内存没有降”追到明确的所有权错误

## 为什么用可控引用环，而不是随机堆内存？

目标是证明原因和修复链条：同一个 3D Controller，唯一变量是闭包是否强捕获自己。代码没有增加几十 MiB 的无用 buffer 来制造漂亮曲线。

```swift
// 注入：Controller → callback → Controller
callback = { self.view.alpha = 1 }
// 修复：闭包不延长 Controller 生命周期
callback = { [weak self] in self?.view.alpha = 1 }
```

SCNView 挂在 Controller.view 下，Controller 不释放便连带保留场景。这里不用“SCNView.delegate 一定强引用”这种未经检查的前提，也不使用 unowned；页面可能提前退出，weak 的 nil 是正常生命周期，不应让它崩溃。

Registry 仅存 weak 引用，避免监测器成为新的持有者。关闭页面后延迟检查，排除转场期间的正常保留；解除注入时清空 callback，再检查是否 deinit。它是有明确故障注入的学习工具，不是对所有线上泄漏的通用判定器。

## 工具选型：Instruments + 对象证据 + display link

| 工具 | 回答什么 | 不能独立证明什么 |
|---|---|---|
| Allocations | 哪些堆分配仍存活，何时分配/释放 | 不直接等同 GPU 资源或进程 footprint |
| Memory Graph / weak registry | 哪个对象活着，谁在保留它 | 存活对象是否一定不符合产品生命周期 |
| Leaks | 符合其可达性检测条件的泄漏 | 没报告不代表没有业务对象引用环 |
| CADisplayLink | 主线程回调频率及长帧时间间隔 | GPU 已完成帧率、阻塞当时的调用栈 |
| Time Profiler | 阻塞/耗时期间的线程采样 | 单张恢复后日志能否还原完整阻塞路径 |

自研监测只覆盖本 Demo 所需的对象与回调。相比引入 MLeaksFinder，依赖少、故障可解释，但不提供完整自动遍历和业务白名单体系。

## 可复现序列，而不是挑两张内存截图

`--memory-benchmark` 启动专门的实验页，依次执行：

1. 等待 3 秒基线；强引用版本打开/关闭 10 次，每次展示约 400 ms、间隔约 400 ms。
2. 保留 10 个泄漏 Controller 约 5 秒。
3. 主动解除全部引用环，等待约 5 秒。
4. weak 版本打开/关闭 10 次，保留结束状态。

实验直接使用 `LeakViewController` 与 SCNView，把子 Controller 真正加入视图层级后移除。阶段时间受系统调度影响，不能把理想时间点当作真实测量时间；原始 trace 与采样表才是证据。它不经过手动转场动画，因此和常规详情页 UI 回归是两个互补测试。

[性能报告](BENCHMARKS.md)列出本次 Instruments 执行结果。若工具没有产出可导出的数据，就只记录失败原因，不能用理论曲线代替。对于已得到的数据，图题必须标注设备/模拟器、Debug/Release、指标名称和数据来源。分配器可能持有已释放内存；对象已释放而 RSS 不立即下降并不矛盾。

## FPS 计算与观测边界

维护约 1 秒滑动窗口，设窗口内第一和最后回调时间为 t0、tn，包含 n 个间隔，则 `FPS = n / (tn - t0)`。不要用某一帧的 `1 / delta` 当作稳定帧率。窗口在后台停止/恢复时重置；display link 注册 common mode，使滚动 tracking 模式仍可回调。

低于 45 FPS 时记录 OSLog，最多每 5 秒一次；注入按钮在主线程周期性 sleep，用来验证掉帧检测与恢复。恢复后的 `Thread.callStackSymbols` 明确标记为 callback stack，它没有能力回溯已经结束的阻塞。真正的堆栈归因应看 Time Profiler，线上可进一步设计 watchdog/MetricKit 管线，但本仓库没有伪装成已完成线上采样。

`--capture-fps` 导出原始时间戳用于计算平均频率、P95 帧间隔和长帧率。截图用于说明正在操作的页面；连续序列用来判断是否稳定。Debug 模拟器自动化不构成“真机滚动稳定 60”的证明。

## 已覆盖与下一步验收

单元测试直接断言 weak 版本释放、强环版本保留、解除后释放；UI 测试经过真实 sheet 关闭流程检查 0 → 1 → 0。最终性能曲线/采样数以 [报告](BENCHMARKS.md) 为准，不能从测试通过次数反推出内存收益。

真机验收需要固定机型、系统、热状态、模式、刷新率和构建，以相同次数对照。保留完整 Instruments trace，不只导出有利的局部截图；报告中同时呈现模型资源、缓存、CPU/GPU 指标和噪声来源。

代码：[引用环与页面](../App/Demos/PerformanceLab.swift)、[重复实验入口](../App/Core/MemoryBenchmark.swift)、[FPS 实现](../App/Core/FPSMonitor.swift)。
