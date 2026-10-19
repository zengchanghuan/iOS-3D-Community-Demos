import SwiftUI
import QuartzCore

struct TextureLab: View {
    @State private var compressed = false
    @State private var report = "加载中"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FilamentCanvas(compressed: compressed, report: $report).frame(minHeight: 260)
                .overlay(alignment: .topTrailing) { FPSBadge().padding() }
            Toggle("ASTC 4×4 对照模型", isOn: $compressed)
            Text(report).font(.system(.caption, design: .monospaced))
            Text("同一源图：1024×1024，sRGB，无 mipmap，线性采样。ASTC 版本在标准 GLB 的 1×1 占位纹理上绑定原生 ASTC sidecar；占位数据在上传前替换。").font(.caption)
            Text("切换差值受 Metal 分配器复用影响。正式报告请在真机分别冷启动两组，预热后重复采样，并使用 Metal Capture 核对纹理格式与资源大小。").font(.caption).foregroundStyle(.secondary)
        }.padding().navigationTitle("Filament · Metal PBR").navigationBarTitleDisplayMode(.inline)
    }
}

struct FilamentCanvas: UIViewRepresentable {
    var compressed: Bool
    @Binding var report: String
    func makeCoordinator() -> Coordinator { Coordinator(report: $report) }
    func makeUIView(context: Context) -> FilamentSurface {
        let view = FilamentSurface(frame: .zero)
        context.coordinator.surface = view
        context.coordinator.start()
        return view
    }
    func updateUIView(_ view: FilamentSurface, context: Context) {
        if context.coordinator.compressed != compressed {
            context.coordinator.compressed = compressed
            view.loadCompressed(compressed)
        }
    }
    static func dismantleUIView(_ uiView: FilamentSurface, coordinator: Coordinator) { coordinator.stop(); uiView.shutdown() }
    final class Coordinator: NSObject {
        weak var surface: FilamentSurface?
        var compressed: Bool?
        var report: Binding<String>
        var link: CADisplayLink?
        private let proxy = Proxy()
        init(report: Binding<String>) { self.report = report }
        private final class Proxy: NSObject {
            weak var owner: Coordinator?
            @objc func tick() { owner?.tick() }
        }
        func start() {
            proxy.owner = self
            let link = CADisplayLink(target: proxy, selector: #selector(Proxy.tick))
            link.add(to: .main, forMode: .common); self.link = link
        }
        func tick() {
            guard let surface else { return }
            surface.renderFrame()
            if report.wrappedValue != surface.report { report.wrappedValue = surface.report }
        }
        func stop() { link?.invalidate(); link = nil }
        deinit { link?.invalidate() }
    }
}
