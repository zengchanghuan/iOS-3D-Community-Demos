import SwiftUI
import QuartzCore
import os

struct FrameWindow {
    private var timestamps: [Double] = []
    mutating func sample(_ timestamp: Double) -> Double? {
        timestamps.append(timestamp)
        while timestamps.count > 2, timestamps[1] < timestamp - 1 { timestamps.removeFirst() }
        guard let first = timestamps.first, timestamp - first >= 0.9 else { return nil }
        return Double(timestamps.count - 1) / (timestamp - first)
    }
    mutating func reset() { timestamps.removeAll(keepingCapacity: true) }
}

@MainActor
final class FPSMonitor: NSObject, ObservableObject {
    @Published var fps: Double = 0
    private var link: CADisplayLink?
    private let proxy = Proxy()
    private var window = FrameWindow()
    private var lastPublish = 0.0
    var context = "view"
    private var recorded: [Double] = []
    private let capture = ProcessInfo.processInfo.arguments.contains("--capture-fps")
    private var lastLog = -Double.infinity
    private let logger = Logger(subsystem: "dev.community3d", category: "FPS")
    @MainActor private final class Proxy: NSObject {
        weak var owner: FPSMonitor?
        @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
    }
    func start() {
        guard link == nil else { return }
        proxy.owner = self; window.reset(); lastPublish = 0; recorded = []
        let link = CADisplayLink(target: proxy, selector: #selector(Proxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }
    func stop() {
        link?.invalidate(); link = nil; window.reset()
        if capture, recorded.count > 2 {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let path = directory.appendingPathComponent("fps-\(context)-\(UUID().uuidString).json")
            let object: [String: Any] = ["context": context, "timestamps": recorded, "metric": "CADisplayLink callback timestamps; not GPU completed frames", "system": UIDevice.current.systemVersion]
            if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) { try? data.write(to: path, options: .atomic) }
            recorded = []
        }
    }
    private func tick(_ link: CADisplayLink) {
        if capture, recorded.count < 36000 { recorded.append(link.timestamp) }
        guard let value = window.sample(link.timestamp), link.timestamp - lastPublish >= 0.25 else { return }
        fps = value; lastPublish = link.timestamp
        if value < 45, link.timestamp - lastLog >= 5 {
            lastLog = link.timestamp
            logger.warning("Low FPS: \(value, privacy: .public); callback stack (after stall, not blocked stack): \(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")
        }
    }
    deinit { link?.invalidate() }
}

struct FPSBadge: View {
    var context = "view"
    @StateObject private var monitor = FPSMonitor()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Text(monitor.fps == 0 ? "— FPS" : String(format: "%.0f FPS", monitor.fps)).monospacedDigit().font(.caption.bold())
            .padding(6).background(.black.opacity(0.7)).foregroundStyle(monitor.fps < 45 ? .orange : .green).clipShape(Capsule())
            .onAppear { monitor.context = context; if phase == .active { monitor.start() } }
            .onDisappear { monitor.stop() }
            .onChange(of: phase) { if $0 == .active { monitor.start() } else { monitor.stop() } }
    }
}
