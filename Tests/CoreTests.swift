import XCTest
import SceneKit
import GLTFSceneKit
@testable import Community3D

final class CoreTests: XCTestCase {
    @MainActor func testDemoCredentials() {
        XCTAssertTrue(DemoAuth.valid(email: " DEMO@3DLAB.LOCAL ", password: "Demo3D!2026"))
        XCTAssertFalse(DemoAuth.valid(email: "demo@3dlab.local", password: "wrong"))
        XCTAssertFalse(DemoAuth.valid(email: "other@3dlab.local", password: "Demo3D!2026"))
    }
    func testFoxClipsAndSkeleton() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Fox", withExtension: "glb"))
        let doc = try ModelDocument(data: Data(contentsOf: url))
        XCTAssertEqual(doc.animationNames, ["Survey", "Walk", "Run"])
        for index in doc.animationNames.indices {
            let selected = try doc.data(animation: index)
            let parsed = try ModelDocument(data: selected)
            XCTAssertEqual(parsed.animationNames, [doc.animationNames[index]])
            let scene = try GLTFSceneSource(data: selected).scene()
            var skeletons = 0, animated = 0
            scene.rootNode.enumerateChildNodes { node, _ in
                if node.skinner != nil { skeletons += 1 }
                animated += node.animationKeys.count
            }
            XCTAssertGreaterThan(skeletons, 0)
            XCTAssertGreaterThan(animated, 0)
        }
    }
    func testAdditionalBundledModels() throws {
        for name in ["CesiumMan", "Avocado", "BoxAnimated"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "glb"))
            let doc = try ModelDocument(data: Data(contentsOf: url))
            XCTAssertEqual(doc.animationNames.isEmpty, name == "Avocado", name)
            let scene = try GLTFSceneSource(data: doc.data(animation: doc.animationNames.isEmpty ? nil : 0)).scene()
            var meshes = 0, skinners = 0, animations = 0
            scene.rootNode.enumerateChildNodes { node, _ in
                if node.geometry != nil { meshes += 1 }
                if node.skinner != nil { skinners += 1 }
                animations += node.animationKeys.count
            }
            XCTAssertGreaterThan(meshes, 0, name)
            if name == "CesiumMan" { XCTAssertGreaterThan(skinners, 0) }
            if name != "Avocado" { XCTAssertGreaterThan(animations, 0, name) }
        }
    }
    func testMalformedGLBRejected() {
        XCTAssertThrowsError(try ModelDocument(data: Data([0x67,0x6c,0x54,0x46,2,0,0,0,12,0,0,0])))
        XCTAssertThrowsError(try ModelDocument(data: Data("{}".utf8)))
    }
    func testExternalResourcesRejectedClearly() {
        let data = Data(#"{"asset":{"version":"2.0"},"buffers":[{"uri":"mesh.bin"}]}"#.utf8)
        XCTAssertThrowsError(try ModelDocument(data: data)) { XCTAssertTrue($0 is ModelDocument.Failure) }
    }
    func testFrameWindowDetectsStallAndRecovers() {
        var window = FrameWindow()
        var fps: Double?
        for i in 0...120 { fps = window.sample(Double(i)/60) }
        XCTAssertEqual(fps ?? 0, 60, accuracy: 0.01)
        let slow = window.sample(2.7)
        XCTAssertLessThan(slow ?? 60, 45)
        for i in 1...120 { fps = window.sample(2.7 + Double(i)/60) }
        XCTAssertEqual(fps ?? 0, 60, accuracy: 0.01)
    }
    @MainActor func testLeakAndWeakFix() {
        weak var fixed: LeakViewController?
        autoreleasepool {
            let controller = LeakViewController(leaking: false)
            controller.loadViewIfNeeded(); fixed = controller
        }
        XCTAssertNil(fixed)
        weak var leaking: LeakViewController?
        autoreleasepool {
            let controller = LeakViewController(leaking: true)
            controller.loadViewIfNeeded(); leaking = controller
        }
        XCTAssertNotNil(leaking)
        LeakRegistry.shared.releaseAll()
        XCTAssertNil(leaking)
    }
}
