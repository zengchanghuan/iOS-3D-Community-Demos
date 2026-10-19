# 真机实验记录规程

已有模拟器 Instruments 曲线和连续 FPS 数据见 [实际性能报告](BENCHMARKS.md)。下表仍是尚未完成的真机验收，不与模拟器数据混用。

## ASTC / Metal

1. 在同一真机、同一系统、同一 Release 构建上关闭其他本 App 页面，保持相同方向与尺寸，固定低电量模式、热状态和刷新率。
2. 分别冷启动 PNG 和 ASTC 两组；等待至少 30 帧预热，采样稳定阶段；每组至少 5 次。当前 App 默认 PNG，ASTC 可切换；正式独立冷启动实验可在 `TextureLab` 将初始值设为 true，记录对应构建。切换实验单独记录，不能混同冷启动数据。
3. Xcode GPU Frame Capture 检查 baseColorMap：1024×1024、1 level，分别 RGBA8 sRGB 与 ASTC 4×4 sRGB；记录 Metal 资源列表中的实际分配。确认 ASTC 分支没有静默解压。
4. 记录 App OSLog 的 device allocated、加载前基线、差值；用 Instruments Allocations / VM Tracker 另记进程内存，单位 MiB。内存池高水位会让释放后的设备量不立即下降。
5. 比较截图清晰度、帧时间和冷启动耗时；只有两种格式、尺寸和采样均一致时才归因。两组均通过自定义 TextureProvider 强制只分配一层 mipmap；默认 StbProvider 会自动生成全 mip 链，不能直接用作此对照。

| 设备 / 系统 / 构建 | 变体 | 冷启动 / 切换 | texture allocated | device allocated | 进程 footprint | 帧时间 | capture 路径 |
|---|---|---|---|---|---|---|---|
| 待测 | PNG | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 |
| 待测 | ASTC 4×4 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 |

不能仅凭纹理 payload 的 75% 理论降幅推出 App 内存下降 75% 或已经防止线上 OOM。

## 引用环 / Instruments

1. Product → Profile → Allocations + Leaks；记录设备、系统、构建、稳定基线。
2. 修复分支打开关闭详情页 10 次，每次关闭后等待过渡结束，检查 registry 存活数为 0、deinit 日志存在。
3. 开启注入再打开关闭 10 次；检查存活 Controller 累积，并用 Xcode Memory Graph 找到 `callback` 闭包反向强引用。Leaks 未报告不代表无引用环；结合 Allocations 的 persistent objects 和 Memory Graph。
4. 保存 trace，点“解除所有实验引用环”，核对实例数回落；不要要求进程 footprint 立即回到基线，图形驱动/缓存可能保留已分配内存。
5. 再次运行修复分支，记录相同次数后的实例数和内存。截图、trace 与真实数字填入下表。

| 分支 | 打开关闭次数 | 存活 Controller | 进程 footprint | 证据 |
|---|---|---|---|---|
| 注入强引用环 | 待测 | 待测 | 待测 | 待测 |
| weak 修复 | 待测 | 待测 | 待测 | 待测 |

## 卡顿

运行 Time Profiler，打开性能页并注入卡顿。预期 1 秒窗口内 FPS 低于 45，Console 搜索 subsystem `dev.community3d` / category `FPS` 出现限频日志。阻塞采样应落在主动 sleep 的主线程调用路径。停止注入后应恢复；退出页面后注入任务取消。

主线程从长阻塞恢复后才能执行 display-link 回调，因此这里没有实现线上任意线程堆栈采集、MetricKit 上传或完整 ANR watchdog。
