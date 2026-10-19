#import "FilamentSurface.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/View.h>
#include <filament/Camera.h>
#include <filament/SwapChain.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/MaterialInstance.h>
#include <filament/IndirectLight.h>
#include <filament/Skybox.h>
#include <filament/LightManager.h>
#include <filament/Viewport.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/MaterialProvider.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/materials/uberarchive.h>
#include <ktxreader/Ktx1Reader.h>
#include <image/Ktx1Bundle.h>
#include <utils/EntityManager.h>
#include <memory>
#include "ControlledTextureProvider.h"

using namespace filament;
using namespace filament::gltfio;
using namespace filament::math;

static NSData *resource(NSString *name, NSString *extension) {
    NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:extension];
    return url ? [NSData dataWithContentsOfURL:url] : nil;
}
struct RenderState {
    Engine *engine = nullptr;
    Renderer *renderer = nullptr;
    Scene *scene = nullptr;
    View *view = nullptr;
    Camera *camera = nullptr;
    SwapChain *swap = nullptr;
    MaterialProvider *materials = nullptr;
    AssetLoader *loader = nullptr;
    FilamentAsset *asset = nullptr;
    Texture *ibl = nullptr;
    IndirectLight *light = nullptr;
    Skybox *sky = nullptr;
    utils::Entity cameraEntity, sun;
    void clearModel() {
        if (asset) { scene->removeEntities(asset->getEntities(), asset->getEntityCount()); loader->destroyAsset(asset); asset = nullptr; }
        if (engine) engine->flushAndWait();
    }
    ~RenderState() {
        if (!engine) return;
        clearModel();
        if (loader) AssetLoader::destroy(&loader);
        if (materials) { materials->destroyMaterials(); delete materials; }
        engine->destroy(view); engine->destroy(scene);
        engine->destroy(light); engine->destroy(sky); engine->destroy(ibl);
        engine->destroy(sun); utils::EntityManager::get().destroy(sun);
        engine->destroyCameraComponent(cameraEntity); utils::EntityManager::get().destroy(cameraEntity);
        engine->destroy(renderer); engine->destroy(swap);
        Engine::destroy(&engine);
    }
};

@implementation FilamentSurface {
    std::unique_ptr<RenderState> _state;
    NSString *_report;
    NSUInteger _baseline;
    NSInteger _frames;
    BOOL _compressed;
}
+ (Class)layerClass { return CAMetalLayer.class; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _report = @"尚未加载";
        self.contentScaleFactor = UIScreen.mainScreen.scale;
        auto s = std::make_unique<RenderState>();
        s->engine = Engine::create(Engine::Backend::METAL);
        if (!s->engine) { _report = @"Metal 引擎初始化失败"; return self; }
        s->swap = s->engine->createSwapChain((__bridge void *)self.layer);
        s->renderer = s->engine->createRenderer();
        s->scene = s->engine->createScene();
        s->view = s->engine->createView();
        s->cameraEntity = utils::EntityManager::get().create();
        s->camera = s->engine->createCamera(s->cameraEntity);
        s->camera->lookAt(double3{4,3,6}, double3{0,0,0});
        s->camera->setExposure(16.0f, 1.0f/125.0f, 100.0f);
        s->view->setScene(s->scene); s->view->setCamera(s->camera);
        s->materials = createUbershaderProvider(s->engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
        s->loader = AssetLoader::create({s->engine, s->materials, nullptr});
        NSData *iblData = resource(@"Studio_ibl", @"ktx");
        if (iblData) {
            auto bundle = new image::Ktx1Bundle((const uint8_t *)iblData.bytes, (uint32_t)iblData.length);
            float3 sh[9]; bundle->getSphericalHarmonics(sh);
            s->ibl = ktxreader::Ktx1Reader::createTexture(s->engine, bundle, false);
            s->light = IndirectLight::Builder().reflections(s->ibl).irradiance(3, sh).intensity(30000).build(*s->engine);
            s->scene->setIndirectLight(s->light);
        }
        s->sky = Skybox::Builder().color({0.025f,0.035f,0.05f,1}).build(*s->engine);
        s->scene->setSkybox(s->sky);
        s->sun = utils::EntityManager::get().create();
        LightManager::Builder(LightManager::Type::DIRECTIONAL).direction({-1,-2,-1}).intensity(60000).castShadows(true).build(*s->engine, s->sun);
        s->scene->addEntity(s->sun);
        _state = std::move(s);
    }
    return self;
}
- (NSString *)report { return _report; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_state || self.bounds.size.height <= 0 || self.bounds.size.width <= 0) return;
    CGSize size = CGSizeMake(self.bounds.size.width*self.contentScaleFactor, self.bounds.size.height*self.contentScaleFactor);
    ((CAMetalLayer *)self.layer).drawableSize = size;
    _state->view->setViewport({0,0,(uint32_t)size.width,(uint32_t)size.height});
    _state->camera->setProjection(45, size.width/size.height, 0.1, 100);
}
- (void)loadCompressed:(BOOL)compressed {
    if (!_state) return;
    auto &s = *_state;
    _frames = 0;
    s.clearModel();
    _compressed = compressed;
    if (compressed && !Texture::isTextureFormatSupported(*s.engine, Texture::InternalFormat::SRGB8_ALPHA8_ASTC_4x4)) {
        _report = @"此设备不支持 ASTC 4×4；请在支持 ASTC 的真机运行。"; return;
    }
    _baseline = ((CAMetalLayer *)self.layer).device.currentAllocatedSize;
    NSData *data = resource(compressed ? @"Checker-ASTC" : @"Checker-PNG", @"glb");
    if (!data) { _report = @"缺少模型资源"; return; }
    s.asset = s.loader->createAsset((const uint8_t *)data.bytes, (uint32_t)data.length);
    if (!s.asset) { _report = @"glTF 解析失败"; return; }
    {
        // Provider must outlive ResourceLoader, whose destructor still visits it.
        std::unique_ptr<TextureProvider> stb(new ControlledTextureProvider(*s.engine, compressed));
        ResourceLoader resources({.engine = s.engine, .normalizeSkinningWeights = true});
        resources.addTextureProvider("image/png", stb.get());
        if (!resources.loadResources(s.asset)) { s.clearModel(); _report = @"glTF 资源加载失败"; return; }
    }
    s.asset->releaseSourceData();
    s.scene->addEntities(s.asset->getEntities(), s.asset->getEntityCount());
    s.engine->flushAndWait();
    _report = @"预热中：30 帧后采样 Metal 设备资源分配量";
}
- (void)renderFrame {
    if (!_state || !self.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive || self.bounds.size.height <= 0) return;
    auto &s = *_state;
    if (s.renderer->beginFrame(s.swap)) { s.renderer->render(s.view); s.renderer->endFrame(); }
    if (s.asset && ++_frames == 30) {
        s.engine->flushAndWait();
        id<MTLDevice> device = ((CAMetalLayer *)self.layer).device;
        NSUInteger current = device ? device.currentAllocatedSize : 0;
        if (!device || current == 0) {
            _report = [NSString stringWithFormat:@"%@ · 已加载\n纹理 payload 理论值：%.2f MiB\nMetal device allocated：不可用（返回 0）\n请用真机 Metal Capture 测量。", _compressed ? @"ASTC 4×4 sRGB" : @"PNG → RGBA8 sRGB", _compressed ? 1.0 : 4.0];
            NSLog(@"[TextureExperiment] %@", _report);
            return;
        }
        _report = [NSString stringWithFormat:@"%@\n纹理 payload 理论值：%.2f MiB\nMetal device allocated：%.2f MiB\n相对本次加载前：%+.2f MiB\n包含渲染目标、缓冲区和分配器；不是独立显存。", _compressed ? @"ASTC 4×4 sRGB" : @"PNG → RGBA8 sRGB", _compressed ? 1.0 : 4.0, current/1048576.0, ((double)current-(double)_baseline)/1048576.0];
        NSLog(@"[TextureExperiment] %@", _report);
    }
}
- (void)shutdown { _state.reset(); }
- (void)dealloc { [self shutdown]; }
@end
