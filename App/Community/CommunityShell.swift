import SwiftUI

struct LibraryModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let resource: String?
    let url: String?
    let tag: String
    static let items = [
        LibraryModel(id: "fox", title: "Fox", subtitle: "把骨骼动画握在手中", symbol: "hare.fill", resource: "Fox", url: nil, tag: "3 段动画 · 离线"),
        LibraryModel(id: "brake-rotor", title: "Brake Rotor · 制动盘", subtitle: "先临三维汽车零件扫描 · 孔位与盘面", symbol: "disc.fill", resource: "BrakeRotor", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "planting-screw", title: "Planting Screw · 种植螺钉", subtitle: "先临三维精密扫描 · 螺纹结构", symbol: "wrench.and.screwdriver.fill", resource: "PlantingScrew", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "impeller", title: "Impeller · 叶轮", subtitle: "先临三维工业扫描 · 曲面叶片", symbol: "fanblades.fill", resource: "Impeller", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "tiny-gear", title: "Tiny Gear · 微型齿轮", subtitle: "先临三维精密扫描 · 齿面细节", symbol: "gearshape.2.fill", resource: "TinyGear", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "casting-part", title: "Casting Part · 工业铸件", subtitle: "先临三维工业扫描 · 276 万三角面", symbol: "gearshape.fill", resource: "CastingPart", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "sofa", title: "Sofa · 沙发", subtitle: "先临三维家居扫描 · 顶点色彩", symbol: "sofa.fill", resource: "Sofa", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "stone-lion", title: "Stone Lion · 石狮", subtitle: "先临三维实物扫描 · 雕刻与纹理", symbol: "pawprint.fill", resource: "StoneLion", url: nil, tag: "实物扫描 · 高清 · 离线"),
        LibraryModel(id: "cesium-man", title: "Cesium Man", subtitle: "人物行走与骨骼蒙皮", symbol: "figure.walk", resource: "CesiumMan", url: nil, tag: "骨骼动画 · 离线"),
        LibraryModel(id: "avocado", title: "Avocado", subtitle: "牛油果的表面纹理与细节", symbol: "leaf.fill", resource: "Avocado", url: nil, tag: "静态贴图 · 离线"),
        LibraryModel(id: "box-animated", title: "Animated Box", subtitle: "盒子的旋转与升降动画", symbol: "shippingbox.fill", resource: "BoxAnimated", url: nil, tag: "节点动画 · 离线"),
        LibraryModel(id: "duck", title: "Duck", subtitle: "从网络抵达你的场景", symbol: "bird.fill", resource: nil, url: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Duck/glTF-Binary/Duck.glb", tag: "网络模型 · GLB"),
        LibraryModel(id: "checker", title: "Material study", subtitle: "几何、贴图与空间关系", symbol: "cube.transparent.fill", resource: "Checker-PNG", url: nil, tag: "材质练习 · 离线")
    ]
}

enum StudioStyle {
    static let ink = Color(red: 0.055, green: 0.08, blue: 0.13)
    static let lime = Color(red: 0.79, green: 0.95, blue: 0.38)
    static let paper = Color(red: 0.95, green: 0.96, blue: 0.94)
}

struct CommunityEntry: View {
    @StateObject private var auth = DemoAuth()
    var body: some View {
        Group {
            if auth.state == .signedIn { CommunityHome(auth: auth) }
            else { LoginScreen(auth: auth) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { if auth.state == .signingIn { auth.signOut() } }
    }
}

private struct LoginScreen: View {
    @ObservedObject var auth: DemoAuth
    @State private var email = DemoAuth.email
    @State private var password = DemoAuth.password
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Label("FORM / 3D", systemImage: "cube.transparent").font(.headline); Spacer(); Text("01 / COMMUNITY").font(.caption.monospaced()) }
                ZStack {
                    Circle().fill(StudioStyle.lime.opacity(0.12)).frame(width: 220, height: 220)
                    Image(systemName: "cube.transparent.fill").font(.system(size: 110, weight: .ultraLight)).foregroundStyle(StudioStyle.lime).rotationEffect(.degrees(-12))
                    Text("EXPLORE IN EVERY DIMENSION").font(.system(size: 9, design: .monospaced)).tracking(2).offset(y: 115)
                }.frame(maxWidth: .infinity).frame(height: 255)
                VStack(alignment: .leading, spacing: 10) {
                    Text("让灵感，\n拥有第三个维度。").font(.system(size: 34, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text("登录模型工作室，探索动画与材质。\n从一个模型开始，理解整个 3D 世界。").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                }
                VStack(alignment: .leading, spacing: 14) {
                    TextField("邮箱", text: $email, prompt: Text("邮箱").foregroundColor(.white.opacity(0.55))).keyboardType(.emailAddress).textContentType(.username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("login.email")
                    Divider().overlay(.white.opacity(0.2))
                    SecureField("密码", text: $password, prompt: Text("密码").foregroundColor(.white.opacity(0.55))).textContentType(.password).accessibilityIdentifier("login.password")
                        .onSubmit { login() }
                }.padding(20).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                if let error = auth.error { Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("login.error") }
                Button(action: login) {
                    HStack {
                        Spacer()
                        if auth.state == .signingIn { ProgressView().tint(StudioStyle.ink) }
                        Text(auth.state == .signingIn ? "正在登录…" : "登录工作室").fontWeight(.semibold)
                        Image(systemName: "arrow.right"); Spacer()
                    }.padding(18).background(StudioStyle.lime, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(StudioStyle.ink)
                }.disabled(auth.state == .signingIn).accessibilityIdentifier("login.submit")
                VStack(alignment: .leading, spacing: 8) {
                    Button("填入演示账号") { email = DemoAuth.email; password = DemoAuth.password }.foregroundStyle(StudioStyle.lime)
                    Text("本地演示 · 不连接认证服务器\n账号 \(DemoAuth.email)  /  密码 \(DemoAuth.password)").font(.caption).foregroundStyle(.white.opacity(0.55)).textSelection(.enabled)
                }
            }.padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
        }.background(StudioStyle.ink).foregroundStyle(.white).toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: auth.state) { if $0 == .signedIn { password = "" } }
    }
    private func login() { auth.signIn(email: email, password: password) }
}

private struct CommunityHome: View {
    @ObservedObject var auth: DemoAuth
    @State private var tab = 0
    @State private var query = ""
    @State private var offlineOnly = false
    private var filtered: [LibraryModel] {
        LibraryModel.items.filter { (!offlineOnly || $0.resource != nil) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.contains(query)) }
    }
    var body: some View {
        VStack(spacing: 0) {
            if tab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FORM / 3D").font(.caption.monospaced()).tracking(2)
                                Text("模型工作室").font(.largeTitle.bold())
                            }
                            Spacer()
                            Button { tab = 1 } label: { Image(systemName: "person.crop.circle.fill").font(.system(size: 38)).foregroundStyle(StudioStyle.ink) }.accessibilityLabel("个人页")
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            Text("FEATURED COLLECTION / 001").font(.caption2.monospaced()).tracking(1)
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("不止观看，\n亲手探索。").font(.system(size: 29, weight: .bold))
                                    Text("旋转 · 缩放 · 骨骼动画").font(.caption).foregroundStyle(.white.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "cube.transparent.fill").font(.system(size: 72)).foregroundStyle(StudioStyle.lime)
                            }
                            NavigationLink { ModelBrowser(initialModel: LibraryModel.items[0]) } label: {
                                Label("探索 Fox", systemImage: "arrow.up.right").font(.subheadline.bold()).foregroundStyle(StudioStyle.ink).padding(.horizontal, 18).padding(.vertical, 12).background(StudioStyle.lime, in: Capsule())
                            }.accessibilityIdentifier("library.featured")
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(StudioStyle.ink, in: RoundedRectangle(cornerRadius: 24)).foregroundStyle(.white)
                        HStack {
                            Image(systemName: "magnifyingglass")
                            TextField("搜索模型", text: $query).accessibilityIdentifier("library.search")
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("清空搜索") }
                        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        HStack {
                            Text("精选模型").font(.title2.bold()); Spacer()
                            Button(offlineOnly ? "离线可用 ✓" : "全部模型") { offlineOnly.toggle() }.font(.caption.bold()).padding(10).background(.white, in: Capsule())
                        }
                        if filtered.isEmpty {
                            VStack(spacing: 10) { Image(systemName: "cube").font(.largeTitle); Text("没有匹配的模型"); Text("换个关键词试试").font(.caption) }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(40)
                        }
                        ForEach(filtered) { item in
                            NavigationLink { ModelBrowser(initialModel: item) } label: {
                                HStack(spacing: 18) {
                                    Image(systemName: item.symbol).font(.system(size: 35)).frame(width: 82, height: 90).background(StudioStyle.paper, in: RoundedRectangle(cornerRadius: 16))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title).font(.title3.bold())
                                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                        Text(item.tag).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right")
                                }.foregroundStyle(StudioStyle.ink).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }.accessibilityIdentifier("model.\(item.id)")
                        }
                        NavigationLink { ModelBrowser() } label: { Label("导入自己的模型", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity).padding() }.buttonStyle(.bordered)
                        Text("\(LibraryModel.items.count) 个精选资产 · glTF 2.0 / GLB").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("library.scroll")
                .overlay(alignment: .topTrailing) { FPSBadge(context: "library").padding(8) }
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 80)).padding(.top, 35)
                        Text("Demo Explorer").font(.title.bold())
                        Text(DemoAuth.email).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 16) {
                            Label("本地演示会话", systemImage: "person.badge.key")
                            Text("登录状态仅保留在当前运行期间。没有上传账号信息，也没有保存密码。").font(.subheadline).foregroundStyle(.secondary)
                            Divider()
                            Label("模型缓存", systemImage: "internaldrive")
                            Text("下载文件保存在沙盒缓存中；可在模型详情内清空。退出登录不删除公共模型缓存。").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        Button("退出登录", role: .destructive) { auth.signOut() }.buttonStyle(.bordered).accessibilityIdentifier("account.signout")
                    }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
                }
            }
            HStack {
                tabButton("发现", icon: "square.grid.2x2", index: 0)
                tabButton("我的", icon: "person.crop.circle", index: 1)
            }.padding(.top, 12).padding(.bottom, 8).background(.white)
        }.background(StudioStyle.paper).foregroundStyle(StudioStyle.ink).tint(StudioStyle.ink)
        .navigationTitle("").toolbarColorScheme(.light, for: .navigationBar)
    }
    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 5) { Image(systemName: icon); Text(title).font(.caption) }.frame(maxWidth: .infinity).foregroundStyle(tab == index ? StudioStyle.ink : .gray)
        }.accessibilityIdentifier("community.tab.\(index)")
    }
}
