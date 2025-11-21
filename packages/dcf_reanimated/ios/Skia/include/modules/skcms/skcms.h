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

typedef struct skcms_Matrix3x3 {
    float vals[9];
} skcms_Matrix3x3;

#ifdef __cplusplus
}
#endif

#endif /* skcms_h */

