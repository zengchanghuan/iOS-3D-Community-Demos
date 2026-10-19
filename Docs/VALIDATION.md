# 验证记录

日期：2026-10-19（Asia/Shanghai）。以下是加入登录/工作室 UI 和性能证据后的当前记录；初版三入口验证已被本轮回归覆盖。

## 构建与依赖

- Xcode 27.1；iPhone 18 Pro / iOS 27.0 模拟器。
- Simulator arm64 Debug 构建成功，包含 Swift、GLTFSceneKit、Objective-C++、Filament。
- generic iOS arm64 Release 无签名构建成功；不等于已安装真机。
- Filament 使用官方 1.78.0 XCFramework；可选源码构建脚本未执行。
- 上游弃用与头文件告警仍存在，未将它们隐藏为“零警告”。

## 自动化：6 个单元测试 + 2 个 UI 测试

单元测试：

1. 演示账号规范化、正确密码及错误凭证拒绝。
2. Fox 三个 animation 可逐一解析，保留 skinner 和节点动画。
3. 非法 GLB / JSON 被拒绝。
4. 外部资源 URI 有明确错误。
5. FPS 窗口识别长帧并恢复。
6. weak 分支可释放，强引用环保留，解除后释放。

UI 测试：

- 登录空字段错误、填入公开演示凭证、进入模型广场、上下滚动、进入 Fox 并旋转、个人页退出、重启后回到登录。
- 登录后的 Fox 加载/暂停，Filament PNG 渲染与 ASTC 不支持提示，真实 sheet 关闭后 Controller 存活数 0→1→0。

2026-10-19 14:58 用例完成，6+2 项全部通过。截图等待导航转场结束再保存，避免把过渡帧当页面设计效果。15:03 修复登录占位文字对比度后，登录/列表 UI 用例再次通过，Release 再次构建成功。

## 实测新增证据

- 14:50 批次记录广场与模型详情的原始 CADisplayLink timestamps；保留全部帧间隔及统计脚本。
- 14:53–14:54 Instruments Allocations 录制 40 秒，核对完整 benchmark 阶段日志。
- 强引用环 10 次存活 10；解除后 0；weak 分支 10 次结束仍 0。
- 已保存真实 Allocations 曲线截图、原始 trace ZIP、截图表格读数。

所有数值、时间口径、原始文件和限制见 [性能报告](BENCHMARKS.md)。不能将模拟器数据作为真机稳定 60 FPS、ASTC 收益或线上 OOM 改善的证据。

## 关键修复

- 资源加载器必须先于 TextureProvider 析构，避免 use-after-free。
- 使用自定义 provider，确保 PNG/ASTC 同为单 mip。
- Metal allocation 返回 0 显示不可用，FPS 初始窗口未就绪显示“—”。
- 实验通过已安装 bundle ID 启动；无完整阶段日志的初始 `.app` 路径录制未纳入性能结论。

## 尚未验证

- ASTC 真机实际渲染和 Metal Capture、实际纹理 allocation、独立冷启动多轮对照。
- 真机 Release 的精确滑动区间、长帧归因、热状态控制与稳定 60 目标。
- 完整网络异常/缓存淘汰矩阵、多点触控自动化、后台恢复。
- Android PBR 画面对照、真实身份服务、线上遥测。

## 复现

```sh
./Scripts/bootstrap.sh
xcodebuild -project Community3D.xcodeproj -scheme Community3D \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -resultBundlePath /tmp/community3d-tests.xcresult test CODE_SIGNING_ALLOWED=NO
xcodebuild -project Community3D.xcodeproj -scheme Community3D \
  -configuration Release -destination 'generic/platform=iOS' \
  build CODE_SIGNING_ALLOWED=NO
```

使用本机可用的模拟器，resultBundlePath 必须不存在。UI 截图位于 [Screenshots](Screenshots)，性能原始数据位于 [Benchmarks](Benchmarks)。

## 15:10 默认凭证调整

按要求将演示账号和密码设为输入框初始值。Simulator Debug 构建成功，重新安装并目视确认两个输入框已自动填写。对应 UI 用例改为验证默认邮箱及直接登录；此小改后未重跑完整自动化套件，上述 6+2 结果属于此前版本。
