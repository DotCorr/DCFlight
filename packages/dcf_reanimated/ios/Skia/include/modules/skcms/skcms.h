/*
 * Minimal stub for skcms.h to satisfy SkColorSpace.h include
 * This is a placeholder - the actual implementation is in the Skia library
 */

#ifndef skcms_h
#define skcms_h

// Minimal definitions needed for SkColorSpace compilation
// The actual implementation is linked from libskia.a

#ifdef __cplusplus
extern "C" {
#endif

// Minimal type definitions
typedef struct skcms_TransferFunction {
    float g, a, b, c, d, e, f;
} skcms_TransferFunction;

// Matrix3x3 should be a 3x3 array structure to match initialization syntax
typedef struct skcms_Matrix3x3 {
    float vals[3][3];
} skcms_Matrix3x3;

// ICC Profile structure - minimal definition
typedef struct skcms_ICCProfile {
    // Minimal fields - actual structure is more complex but this satisfies compilation
    unsigned char data[1]; // Placeholder
} skcms_ICCProfile;

// Pixel format enum - used by SkCodec
typedef enum {
    skcms_PixelFormat_RGBA_8888,
    skcms_PixelFormat_BGRA_8888,
    skcms_PixelFormat_RGB_565,
    skcms_PixelFormat_RGBA_1010102,
    skcms_PixelFormat_RGB_101010x,
    skcms_PixelFormat_Gray_8,
    skcms_PixelFormat_RGBA_F16,
    skcms_PixelFormat_RGBA_F32,
    skcms_PixelFormat_RGBA_F16Norm,
    skcms_PixelFormat_RGBA_F32Norm,
    skcms_PixelFormat_RGB_888,
    skcms_PixelFormat_RGBA_8888_sRGB,
    skcms_PixelFormat_BGRA_8888_sRGB,
    skcms_PixelFormat_RGBA_1010102_sRGB,
    skcms_PixelFormat_BGRA_1010102,
    skcms_PixelFormat_BGRA_1010102_sRGB,
    skcms_PixelFormat_RGB_101010x_sRGB,
    skcms_PixelFormat_BGR_101010x,
    skcms_PixelFormat_BGR_101010x_sRGB,
    skcms_PixelFormat_BGR_888,
    skcms_PixelFormat_RGBA_8888_Palette8,
    skcms_PixelFormat_BGRA_8888_Palette8,
} skcms_PixelFormat;

// Alpha format enum - used by SkCodec
typedef enum {
    skcms_AlphaFormat_Opaque,
    skcms_AlphaFormat_Unpremul,
    skcms_AlphaFormat_PremulAsEncoded,
} skcms_AlphaFormat;

#ifdef __cplusplus
}
#endif

#endif /* skcms_h */

