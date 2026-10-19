import SwiftUI

@main
struct Community3DApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--memory-benchmark") {
                MemoryBenchmark()
            } else {
                NavigationStack {
                    List {
                        NavigationLink("01 · 模型浏览与骨骼动画") { CommunityEntry() }
                        NavigationLink("02 · PBR 与纹理内存实验") { TextureLab() }
                        NavigationLink("03 · 泄漏与帧率实验") { PerformanceLab() }
                    }
                    .navigationTitle("3D Lab")
                }
            }
        }
    }
}
