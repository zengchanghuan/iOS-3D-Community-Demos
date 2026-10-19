import Foundation

/// Keeps the BIN chunk unchanged while selecting one complete glTF animation clip.
/// GLTFSceneKit otherwise attaches channels from every clip at the same time.
struct ModelDocument {
    enum Failure: LocalizedError {
        case invalid, externalResources
        var errorDescription: String? {
            switch self {
            case .invalid: return "不是有效的 glTF 2.0 / GLB 文件。"
            case .externalResources: return "请导入内嵌资源的 glTF 或 GLB；此入口不支持外部 .bin / 图片文件。"
            }
        }
    }
    private var json: [String: Any]
    private var chunks: [(UInt32, Data)] = []
    private var binary = false
    var animationNames: [String] {
        (json["animations"] as? [[String: Any]] ?? []).enumerated().map {
            $0.element["name"] as? String ?? "动画 \($0.offset + 1)"
        }
    }
    init(data: Data) throws {
        func word(_ offset: Int) -> UInt32 {
            data[offset..<offset + 4].enumerated().reduce(0) { $0 | UInt32($1.element) << ($1.offset * 8) }
        }
        var jsonData = data
        if data.count >= 12, word(0) == 0x46546c67 {
            binary = true
            guard word(4) == 2, Int(word(8)) == data.count else { throw Failure.invalid }
            var cursor = 12
            var first = true
            while cursor < data.count {
                guard cursor + 8 <= data.count else { throw Failure.invalid }
                let size = Int(word(cursor)), type = word(cursor + 4)
                cursor += 8
                guard size % 4 == 0, size <= data.count - cursor else { throw Failure.invalid }
                let payload = data.subdata(in: cursor..<cursor + size)
                if first {
                    guard type == 0x4e4f534a else { throw Failure.invalid }
                    jsonData = payload
                    first = false
                } else { chunks.append((type, payload)) }
                cursor += size
            }
            guard !first else { throw Failure.invalid }
        }
        guard let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let asset = object["asset"] as? [String: Any], asset["version"] as? String == "2.0" else { throw Failure.invalid }
        json = object
        for key in ["buffers", "images"] {
            for item in object[key] as? [[String: Any]] ?? [] {
                if let uri = item["uri"] as? String, !uri.hasPrefix("data:") { throw Failure.externalResources }
            }
        }
    }
    func data(animation index: Int?) throws -> Data {
        var object = json
        if let index {
            let clips = json["animations"] as? [[String: Any]] ?? []
            guard clips.indices.contains(index) else { throw Failure.invalid }
            object["animations"] = [clips[index]]
        } else { object.removeValue(forKey: "animations") }
        var payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard binary else { return payload }
        while payload.count % 4 != 0 { payload.append(0x20) }
        var output = Data()
        func appendWord(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { output.append(contentsOf: $0) }
        }
        appendWord(0x46546c67); appendWord(2)
        appendWord(UInt32(12 + 8 + payload.count + chunks.reduce(0) { $0 + 8 + $1.1.count }))
        appendWord(UInt32(payload.count)); appendWord(0x4e4f534a); output.append(payload)
        for (type, bytes) in chunks { appendWord(UInt32(bytes.count)); appendWord(type); output.append(bytes) }
        return output
    }
}
