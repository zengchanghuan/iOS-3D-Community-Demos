import SwiftUI
import SceneKit

/// Opt-in Instruments fixture. It presents the real demo controller, then removes it.
/// No synthetic megabyte buffers are allocated to exaggerate the leak.
struct MemoryBenchmark: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BenchmarkController { BenchmarkController() }
    func updateUIViewController(_ controller: BenchmarkController, context: Context) {}
}

final class BenchmarkController: UIViewController {
    private let label = UILabel()
    private var work: Task<Void, Never>?
    private var events: [[String: Any]] = []
    private let began = ProcessInfo.processInfo.systemUptime
    private func mark(_ phase: String) {
        LeakRegistry.shared.refresh()
        events.append(["elapsed_s": ProcessInfo.processInfo.systemUptime - began, "phase": phase, "survivors": LeakRegistry.shared.survivors])
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("memory-events.json")
        if let data = try? JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted]) { try? data.write(to: file, options: .atomic) }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 20, y: 70, width: 350, height: 80)
        label.numberOfLines = 0; view.addSubview(label)
        mark("baseline")
        work = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            for iteration in 0..<10 {
                guard !Task.isCancelled, let self else { return }
                self.label.text = "Instruments fixture · retain cycle\nCycle \(iteration + 1) / 10"
                await self.cycle(leaking: true)
                self.mark("retained")
            }
            self?.label.text = "10 leaked controllers · hold 5 seconds"
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self?.mark("before_release")
            LeakRegistry.shared.releaseAll()
            self?.mark("released")
            self?.label.text = "Cycles released · hold 5 seconds"
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            for iteration in 0..<10 {
                guard !Task.isCancelled, let self else { return }
                self.label.text = "Instruments fixture · weak capture\nCycle \(iteration + 1) / 10"
                await self.cycle(leaking: false)
                self.mark("weak")
            }
            LeakRegistry.shared.refresh()
            self?.mark("finished")
            self?.label.text = "Finished · surviving controllers: \(LeakRegistry.shared.survivors)"
        }
    }
    @MainActor private func cycle(leaking: Bool) async {
        var child: LeakViewController? = LeakViewController(leaking: leaking)
        if let child {
            addChild(child)
            child.view.frame = CGRect(x: 20, y: 170, width: 320, height: 360)
            view.addSubview(child.view); child.didMove(toParent: self)
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        child?.willMove(toParent: nil); child?.view.removeFromSuperview(); child?.removeFromParent(); child = nil
        LeakRegistry.shared.refresh()
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
    deinit { work?.cancel() }
}
