//
//  field.h
//  RayRacer
//
//  Created by Serge Tsyba on 23.5.2026.
//

#ifndef field_h
#define field_h

// expose types to Metal
#ifdef __METAL_VERSION__
#include <metal_stdlib>

using namespace metal;

typedef struct {
	uint2 field_size;
	uint2 image_size;
	uint2 image_origin;
} field_geometry;

// expose types to Swift
#else
#include <simd/simd.h>

typedef struct {
	simd_uint2 field_size;
	simd_uint2 image_size;
	simd_uint2 image_origin;
} field_geometry;

#endif

#endif /* field_h */
