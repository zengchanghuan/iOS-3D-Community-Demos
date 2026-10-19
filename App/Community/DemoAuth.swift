import Foundation

/// Intentionally local demo authentication. No server token or persisted password.
@MainActor
final class DemoAuth: ObservableObject {
    enum State: Equatable { case signedOut, signingIn, signedIn }
    @Published private(set) var state: State = .signedOut
    @Published private(set) var error: String?
    static let email = "demo@3dlab.local"
    static let password = "Demo3D!2026"
    private var task: Task<Void, Never>?

    static func valid(email: String, password: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Self.email && password == Self.password
    }
    func signIn(email: String, password: String) {
        guard state != .signingIn else { return }
        error = nil
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            error = "请填写邮箱和密码"; return
        }
        state = .signingIn
        task = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard let self, !Task.isCancelled else { return }
            if Self.valid(email: email, password: password) { self.state = .signedIn }
            else { self.state = .signedOut; self.error = "账号或密码不正确，请使用下方演示账号" }
        }
    }
    func signOut() { task?.cancel(); task = nil; state = .signedOut; error = nil }
}
