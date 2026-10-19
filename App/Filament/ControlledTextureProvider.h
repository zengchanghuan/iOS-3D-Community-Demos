#pragma once
#include <gltfio/TextureProvider.h>
#include <filament/Texture.h>
#include <vector>

// Fixed-fixture provider: both paths explicitly allocate exactly one mip level.
// Filament's default StbProvider generates a full mip chain unconditionally.
class ControlledTextureProvider final : public filament::gltfio::TextureProvider {
    filament::Engine &engine;
    bool compressed;
    std::vector<Texture *> pending, ready;
    size_t pushed = 0, popped = 0, decoded = 0;
    const char *message = nullptr;
public:
    ControlledTextureProvider(filament::Engine &engine, bool compressed) : engine(engine), compressed(compressed) {}
    Texture *pushTexture(const uint8_t *data, size_t count, const char *, TextureFlags flags) override {
        using namespace filament;
        message = nullptr;
        Texture *texture = nullptr;
        const bool srgb = (uint64_t(flags) & uint64_t(TextureFlags::sRGB)) != 0;
        auto release = [](void *p, size_t, void *) { free(p); };
        if (compressed) {
            NSURL *url = [NSBundle.mainBundle URLForResource:@"Checker" withExtension:@"astc"];
            NSData *bytes = url ? [NSData dataWithContentsOfURL:url] : nil;
            const uint8_t *p = (const uint8_t *)bytes.bytes;
            const uint8_t expected[] = {0x13,0xab,0xa1,0x5c,4,4,1,0,4,0,0,4,0,1,0,0};
            if (bytes.length != 16 + 1024*1024 || memcmp(p, expected, 16) != 0) { message = "Invalid ASTC fixture"; return nullptr; }
            texture = Texture::Builder().width(1024).height(1024).levels(1)
                .format(srgb ? Texture::InternalFormat::SRGB8_ALPHA8_ASTC_4x4 : Texture::InternalFormat::RGBA_ASTC_4x4).build(engine);
            void *copy = malloc(bytes.length-16); memcpy(copy, p+16, bytes.length-16);
            Texture::PixelBufferDescriptor buffer(copy, bytes.length-16,
                srgb ? backend::CompressedPixelDataType::SRGB8_ALPHA8_ASTC_4x4 : backend::CompressedPixelDataType::RGBA_ASTC_4x4,
                (uint32_t)bytes.length-16, release);
            texture->setImage(engine, 0, std::move(buffer));
        } else {
            UIImage *image = [UIImage imageWithData:[NSData dataWithBytes:data length:count]];
            CGImageRef cg = image.CGImage;
            if (!cg) { message = "PNG decode failed"; return nullptr; }
            size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
            void *pixels = calloc(w*h, 4);
            CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef context = CGBitmapContextCreate(pixels, w, h, 8, w*4, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(color);
            if (!context) { free(pixels); message = "PNG bitmap context failed"; return nullptr; }
            CGContextDrawImage(context, CGRectMake(0,0,w,h), cg); CGContextRelease(context);
            texture = Texture::Builder().width((uint32_t)w).height((uint32_t)h).levels(1)
                .format(srgb ? Texture::InternalFormat::SRGB8_A8 : Texture::InternalFormat::RGBA8).build(engine);
            Texture::PixelBufferDescriptor buffer(pixels, w*h*4, backend::PixelDataFormat::RGBA, backend::PixelDataType::UBYTE, release);
            texture->setImage(engine, 0, std::move(buffer));
        }
        pending.push_back(texture); ++pushed; return texture;
    }
    void updateQueue() override { decoded += pending.size(); ready.insert(ready.end(), pending.begin(), pending.end()); pending.clear(); }
    Texture *popTexture() override { if (ready.empty()) return nullptr; auto t = ready.back(); ready.pop_back(); ++popped; return t; }
    const char *getPushMessage() const override { return message; }
    const char *getPopMessage() const override { return nullptr; }
    void waitForCompletion() override {}
    void cancelDecoding() override {}
    size_t getPushedCount() const override { return pushed; }
    size_t getPoppedCount() const override { return popped; }
    size_t getDecodedCount() const override { return decoded; }
};
