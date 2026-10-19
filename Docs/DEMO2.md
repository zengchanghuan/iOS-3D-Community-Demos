# Demo 2 · 用共用渲染管线控制 PBR，用格式证据解释内存

## 为什么选 Filament，而不继续用 SceneKit？

Demo 1 解决原生交互，Demo 2 关注 **iOS / Android 的 PBR 效果一致性与可控资源格式**。SceneKit 只覆盖 Apple 平台；如果 Android 换另一套引擎，材质参数、BRDF 实现、环境预过滤和色调映射都可能不同，同一资产便需要两套调校。

Filament 提供跨平台 C++ 渲染核心和材质/光照模型，可以让两端共享引擎版本、glTF 资产、材质参数、IBL 烘焙和后处理配置。iOS 用 Metal 后端，Android 可选 Vulkan/OpenGL。共用管线减少两套实现造成的差异；**它不保证不同 GPU、曝光、色彩空间、纹理转码与显示屏下逐像素相等**。本仓库只实现了 iOS，还没有 Android 对照截图，双端一致性是选型理由和后续验收目标。

依据：[Filament 平台介绍](https://google.github.io/filament/dup/intro.html)、[PBR 理论与光照模型](https://google.github.io/filament/Filament.html)、[材质参数参考](https://google.github.io/filament/Materials.md.html)。

| 方向 | SceneKit | 本 Demo 的 Filament |
|---|---|---|
| Swift/UIKit 集成成本 | 较低 | 增加 Objective-C++ 与 C++ 生命周期管理 |
| 双端共享渲染核心 | 不覆盖 Android | 可复用同一渲染核心、材质与 IBL |
| 纹理上传格式控制 | 高层 API 为主 | 自定义 TextureProvider 明确上传格式 |
| 构建维护 | Apple SDK 内建 | 固定 SDK、headers、materials 版本，包体和构建复杂度增加 |

这里没有测出“Filament 比 SceneKit 快多少”；那需要相同资产、光照、画质、分辨率和设备的独立基准。

## 渲染路径与所有权

```text
SwiftUI → FilamentSurface (Objective-C++) → CAMetalLayer
                                       → Engine / Renderer / View / Scene
                                       → gltfio AssetLoader + ResourceLoader
                                       → ControlledTextureProvider
```

Swift 保留页面状态，桥接层持有 engine、swapchain、camera、scene 和资产。渲染由 CADisplayLink 驱动；退出页面停掉回调后先销毁模型，再销毁材质与引擎资源。weak proxy 防止 display link 把页面永久保留。

一个真实踩坑是 ResourceLoader 析构时仍访问 TextureProvider。C++ 局部变量逆序析构，因此先声明 provider、后声明 loader；如果反过来，编译正常、运行却会 use-after-free。本次 UI 测试在进入 Filament 页时发现该问题，修复后才通过。

PBR 使用原创 checker cube + ground、metallic/roughness 材质、cmgen 预过滤的 HDR studio IBL、方向光和阴影。IBL 包含反射与球谐 irradiance；原始 HDR 与资源生成脚本保留在仓库，便于重建。当前默认加载官方 1.78.0 iOS XCFramework；源码构建脚本另附，未把预编译集成写成已完成本地引擎编译。

## ASTC 对照：先控制变量，再谈节省

PNG 是传输/磁盘编码，不是 GPU 采样时的 RGBA8 资源大小。比较 `.png` 与 `.astc` 文件长度，无法说明 GPU 内存占用。

两组均来自相同的 1024×1024 RGBA 源图，sRGB，单 mip，线性采样，相同几何、相机和光照。PNG 组由 CoreGraphics 解码成 RGBA8；ASTC 组使用 ARM astcenc 5.7.0 生成的原生 ASTC 4×4 block。

ASTC 变体采用标准 GLB 占位图片 + sidecar。ControlledTextureProvider 在上传前替换占位 bytes，因此不会额外分配 1×1 占位纹理。它是限定实验资产的适配器，不是通用 glTF ASTC 扩展；不是 `KHR_texture_basisu` 自动保证 ASTC 的实现。实际生产 KTX2/Basis 流程仍需验证设备最终转码格式。

```text
RGBA8 payload = width × height × 4
              = 1024 × 1024 × 4 = 4 MiB
ASTC 4×4      = ceil(width / 4) × ceil(height / 4) × 16
              = 256 × 256 × 16 = 1 MiB
理论节省     = 1 - 1 / 4 = 75%
```

这是精确的 **纹理 payload 理论值**，不含 mipmap、驱动对齐、堆/分配器、渲染目标、其他贴图与 CPU 解码峰值。默认 StbProvider 无条件生成全 mip 链，本 Demo 特意替换它，避免 PNG 多 mip、ASTC 单 mip 的不公平对比。

## 为什么不把设备分配量写成“显存下降 75%”？

iOS 使用统一内存；`MTLDevice.currentAllocatedSize` 是设备资源当前分配量，包含纹理与 buffers 等，不是 command buffer 个数，也不是进程 footprint。加载前后差值还受池复用、预热及之前场景影响。代码在 30 帧预热后打印它；返回 0 或拿不到 device 时显示不可用，不输出“零显存”。

[实际证据与待测项](BENCHMARKS.md)保留在一处。本机模拟器不支持 ASTC，已验证拒绝分支；**ASTC 真机渲染、Metal Capture 资源大小和 OOM 改善尚未实测**。PNG 已有真实渲染截图。达到完整验收还需：真机两组独立冷启动各至少 5 次，确认 capture 中 format/levels/dimensions 一致，报告 texture allocation、device allocation、进程 footprint、加载峰值和帧时间。

## 复现与边界

- [桥接代码](../App/Filament/FilamentSurface.mm)、[固定资产纹理提供器](../App/Filament/ControlledTextureProvider.h)
- [资源生成](../Scripts/rebuild-textures.sh)、[源码构建入口](../Scripts/build-filament-source.sh)
- [完整真机实验规程](EXPERIMENTS.md)

当前适配器只服务内置不透明 checker 图片；未实现任意 glTF 材质贴图、alpha unpremultiply、mipmap ASTC 链或高分辨率资产流式加载。将这段实验代码推广为生产加载器，需要扩展 MIME/贴图角色映射和资源错误处理。
