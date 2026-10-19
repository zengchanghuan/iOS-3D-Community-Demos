import SwiftUI
import SceneKit
import os

@MainActor
final class LeakRegistry: ObservableObject {
    static let shared = LeakRegistry()
    final class Entry { weak var value: LeakViewController?; init(_ value: LeakViewController) { self.value = value } }
    private var entries: [Entry] = []
    @Published var survivors = 0
    func register(_ value: LeakViewController) { entries.append(Entry(value)) }
    func refresh() { entries.removeAll { $0.value == nil }; survivors = entries.count }
    func releaseAll() { entries.forEach { $0.value?.callback = nil }; refresh() }
}

final class LeakViewController: UIViewController {
    var callback: (() -> Void)?
    private let leaking: Bool
    init(leaking: Bool) { self.leaking = leaking; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        let sceneView = SCNView(frame: .zero)
        let scene = SCNScene()
        let node = SCNNode(geometry: SCNSphere(radius: 1))
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal
        scene.rootNode.addChildNode(node)
        sceneView.scene = scene; sceneView.autoenablesDefaultLighting = true; sceneView.allowsCameraControl = true
        view = sceneView
        if leaking { callback = { self.view.alpha = 1 } }
        else { callback = { [weak self] in self?.view.alpha = 1 } }
        LeakRegistry.shared.register(self)
    }
    deinit { Logger(subsystem: "dev.community3d", category: "Lifetime").info("LeakViewController deinit") }
}

struct LeakPage: UIViewControllerRepresentable {
    let leaking: Bool
    func makeUIViewController(context: Context) -> LeakViewController { LeakViewController(leaking: leaking) }
    func updateUIViewController(_ uiViewController: LeakViewController, context: Context) {}
}

struct PerformanceLab: View {
    @StateObject private var registry = LeakRegistry.shared
    @State private var leaking = false
    @State private var show = false
    @State private var stalling = false
    @State private var stallTask: Task<Void, Never>?
    var body: some View {
        Form {
            Section("引用环实验") {
                Toggle("注入闭包强引用环", isOn: $leaking)
                Button("打开 3D 详情页") { show = true }
                Text("关闭详情页后仍存活：\(registry.survivors)")
                Button("检查存活对象") { registry.refresh() }
                Button("解除所有实验引用环") { registry.releaseAll() }
                Text("Registry 只持有 weak 引用。开启注入后，Controller → closure → Controller 形成环；修复分支使用 [weak self]。").font(.caption)
            }
            Section("主线程帧率") {
                FPSBadge()
                Button(stalling ? "停止卡顿注入" : "注入 3 秒主线程卡顿") {
                    if stalling { stallTask?.cancel(); stalling = false }
                    else {
                        stalling = true
                        stallTask = Task { @MainActor in
                            for _ in 0..<15 {
                                if Task.isCancelled { break }
                                Thread.sleep(forTimeInterval: 0.08)
                                try? await Task.sleep(nanoseconds: 120_000_000)
                            }
                            stalling = false
                        }
                    }
                }
                Text("1 秒滑动窗口；低于 45 FPS 每 5 秒最多记录一次。日志中的栈是恢复后的回调栈；真正阻塞点用 Instruments Time Profiler 定位。").font(.caption)
            }
        }.navigationTitle("性能治理实验")
        .sheet(isPresented: $show, onDismiss: {
            Task { try? await Task.sleep(nanoseconds: 500_000_000); registry.refresh() }
        }) { LeakPage(leaking: leaking).overlay(alignment: .topTrailing) { Button("关闭") { show = false }.padding() } }
        .onDisappear { stallTask?.cancel(); stalling = false }
    }
}
