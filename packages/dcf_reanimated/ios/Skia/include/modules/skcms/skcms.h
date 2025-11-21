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

#ifdef __cplusplus
}
#endif

#endif /* skcms_h */

