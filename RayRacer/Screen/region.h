//
//  region.h
//  RayRacer
//
//  Created by Serge Tsyba on 23.5.2026.
//

#ifndef region_h
#define region_h

// expose types to Metal
#ifdef __METAL_VERSION__
#include <metal_stdlib>

using namespace metal;

typedef struct {
	uint2 origin;
	uint2 size;
} region;

// expose types to Swift
#else
#include <simd/simd.h>

typedef struct {
	simd_uint2 origin;
	simd_uint2 size;
} region;

#endif

#endif /* region_h */
