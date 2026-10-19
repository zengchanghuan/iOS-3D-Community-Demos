import SwiftUI
import SceneKit
import GLTFSceneKit
import UniformTypeIdentifiers

@MainActor
final class ModelSession: ObservableObject {
    @Published var scene = SCNScene()
    @Published var names: [String] = []
    @Published var selected = 0
    @Published var paused = false
    @Published var status = "请选择本地或网络模型"
    @Published var busy = false
    @Published var nodes = ""
    private var document: ModelDocument?
    private var task: Task<Void, Never>?
    func load(_ operation: @escaping () async throws -> Data) {
        task?.cancel()
        busy = true
        task = Task {
            do {
                let data = try await operation()
                try Task.checkCancellation()
                let document = try ModelDocument(data: data)
                self.document = document
                names = document.animationNames
                selected = 0
                try await render(document)
            } catch is CancellationError { return }
            catch { if !Task.isCancelled { status = error.localizedDescription } }
            if !Task.isCancelled { busy = false }
        }
    }
    func choose() {
        guard let document else { return }
        task?.cancel()
        busy = true
        task = Task {
            do { try await render(document) }
            catch { if !Task.isCancelled { status = error.localizedDescription } }
            if !Task.isCancelled { busy = false }
        }
    }
    private func render(_ document: ModelDocument) async throws {
        let bytes = try document.data(animation: names.isEmpty ? nil : selected)
        let result = try await Task.detached(priority: .userInitiated) {
            try GLTFSceneSource(data: bytes).scene()
        }.value
        try Task.checkCancellation()
        scene = result
        paused = false
        var lines: [String] = []
        func walk(_ node: SCNNode, depth: Int) {
            lines.append(String(repeating: "  ", count: depth) + (node.name ?? "node") + (node.skinner == nil ? "" : " [skinner]"))
            node.childNodes.forEach { walk($0, depth: depth + 1) }
        }
        walk(result.rootNode, depth: 0)
        nodes = lines.joined(separator: "\n")
        status = "\(lines.count) 个节点 · \(names.count) 个动画片段"
    }
    func cancel() { task?.cancel(); task = nil }
}

struct ModelBrowser: View {
    var initialModel: LibraryModel? = nil
    @State private var loadedInitial = false
    @StateObject private var model = ModelSession()
    @State private var importing = false
    @State private var tree = false
    @State private var address = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Fox/glTF-Binary/Fox.glb"
    var body: some View {
        VStack(spacing: 10) {
            SceneCanvas(scene: model.scene, paused: model.paused)
                .overlay(alignment: .topTrailing) { FPSBadge(context: "model").padding(8) }
                .frame(minHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .accessibilityIdentifier("model.canvas")
            Text("单指旋转 · 双指捏合缩放 · 三指平移").font(.caption)
            Text(model.status).font(.caption).foregroundStyle(.secondary)
            if model.busy { ProgressView() }
            if !model.names.isEmpty {
                Picker("骨骼动画", selection: $model.selected) {
                    ForEach(Array(model.names.enumerated()), id: \.offset) { index, name in Text(name).tag(index) }
                }.onChange(of: model.selected) { _ in model.choose() }
                Button(model.paused ? "继续动画" : "暂停动画") { model.paused.toggle() }
            }
            Menu("网络模型列表") {
                Button("Fox · 三段骨骼动画") {
                    address = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Fox/glTF-Binary/Fox.glb"
                }
                Button("Duck · 静态模型") {
                    address = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Duck/glTF-Binary/Duck.glb"
                }
            }
            TextField("HTTPS 模型地址", text: $address).textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            HStack {
                Button("网络加载") {
                    guard let url = URL(string: address) else { model.status = "无效 URL"; return }
                    model.load { try await ModelCache.shared.load(url) }
                }
                Button("本地文件") { importing = true }
                Button("示例") {
                    model.load {
                        guard let url = Bundle.main.url(forResource: "Fox", withExtension: "glb") else { throw URLError(.fileDoesNotExist) }
                        return try Data(contentsOf: url)
                    }
                }
            }
            HStack {
                Button("节点树") { tree = true }
                Button("清空缓存") {
                    Task {
                        do { try await ModelCache.shared.clear(); model.status = "缓存已清空" }
                        catch { model.status = error.localizedDescription }
                    }
                }
            }
        }.padding().navigationTitle(initialModel?.title ?? "模型导入").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                model.load {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 64 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
                    return try Data(contentsOf: url)
                }
            case .failure(let error): model.status = error.localizedDescription
            }
        }
        .sheet(isPresented: $tree) { ScrollView { Text(model.nodes).font(.system(.caption, design: .monospaced)).padding() } }
        .onAppear {
            guard !loadedInitial, let item = initialModel else { return }
            loadedInitial = true
            if let name = item.resource {
                model.load {
                    guard let url = Bundle.main.url(forResource: name, withExtension: "glb") else { throw URLError(.fileDoesNotExist) }
                    return try Data(contentsOf: url)
                }
            } else if let text = item.url, let url = URL(string: text) {
                address = text
                model.load { try await ModelCache.shared.load(url) }
            }
        }
        .onDisappear { model.cancel() }
    }
}

struct SceneCanvas: UIViewRepresentable {
    let scene: SCNScene
    let paused: Bool
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)
        view.autoenablesDefaultLighting = true
        view.isPlaying = true
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        let rotate = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.rotate(_:)))
        rotate.maximumNumberOfTouches = 1
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.minimumNumberOfTouches = 3; pan.maximumNumberOfTouches = 3
        let zoom = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.zoom(_:)))
        [rotate, pan, zoom].forEach { view.addGestureRecognizer($0) }
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        if c.source !== scene {
            c.source = scene
            let display = SCNScene()
            let pivot = SCNNode()
            // Keep the original node hierarchy and skeleton references intact.
            display.rootNode.addChildNode(pivot)
            pivot.addChildNode(scene.rootNode)
            let (minimum, maximum) = pivot.boundingBox
            let center = SCNVector3((minimum.x + maximum.x)/2, (minimum.y + maximum.y)/2, (minimum.z + maximum.z)/2)
            let radius = max(0.01, max(maximum.x-minimum.x, max(maximum.y-minimum.y, maximum.z-minimum.z)))
            pivot.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
            pivot.scale = SCNVector3(2/radius, 2/radius, 2/radius)
            let camera = SCNNode(); camera.camera = SCNCamera()
            camera.position = SCNVector3(0, 0, 4)
            camera.camera?.zNear = 0.001; camera.camera?.zFar = 1000
            display.rootNode.addChildNode(camera)
            view.scene = display; view.pointOfView = camera
            c.pivot = pivot; c.camera = camera
        }
        scene.rootNode.isPaused = paused
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { view.isPlaying = false; view.scene = nil }
    final class Coordinator: NSObject {
        weak var source: SCNScene?
        var pivot: SCNNode?; var camera: SCNNode?
        @objc func rotate(_ recognizer: UIPanGestureRecognizer) {
            let delta = recognizer.translation(in: recognizer.view)
            pivot?.eulerAngles.y += Float(delta.x) * 0.008
            pivot?.eulerAngles.x += Float(delta.y) * 0.008
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            let delta = recognizer.translation(in: recognizer.view)
            pivot?.position.x += Float(delta.x) * 0.005
            pivot?.position.y -= Float(delta.y) * 0.005
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        @objc func zoom(_ recognizer: UIPinchGestureRecognizer) {
            guard let camera else { return }
            camera.position.z = min(30, max(0.5, camera.position.z / Float(recognizer.scale)))
            recognizer.scale = 1
        }
    }
}
