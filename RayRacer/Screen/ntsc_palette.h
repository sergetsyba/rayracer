//
//  ntsc_palette.h
//  RayRacer
//
//  Created by Serge Tsyba on 1.9.2024.
//

#ifndef ntsc_palette_h
#define ntsc_palette_h

// expose palette to Metal
#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
constant uint3 ntsc_palette[] = {

// expose palette to Swift
#else
#include <simd/simd.h>
const simd_uint3 ntsc_palette[] = {

#endif
	{0x00, 0x00, 0x00},
	{0x40, 0x40, 0x40},
	{0x6c, 0x6c, 0x6c},
	{0x90, 0x90, 0x90},
	{0xb0, 0xb0, 0xb0},
	{0xc8, 0xc8, 0xc8},
	{0xdc, 0xdc, 0xdc},
	{0xec, 0xec, 0xec},
	{0x44, 0x44, 0x00},
	{0x64, 0x64, 0x10},
	{0x84, 0x84, 0x24},
	{0xa0, 0xa0, 0x34},
	{0xb8, 0xb8, 0x40},
	{0xd0, 0xd0, 0x50},
	{0xe8, 0xe8, 0x5c},
	{0xfc, 0xfc, 0x68},
	{0x70, 0x28, 0x00},
	{0x84, 0x44, 0x14},
	{0x98, 0x5c, 0x28},
	{0xac, 0x78, 0x3c},
	{0xbc, 0x8c, 0x4c},
	{0xcc, 0xa0, 0x5c},
	{0xdc, 0xb4, 0x68},
	{0xec, 0xc8, 0x78},
	{0x84, 0x18, 0x00},
	{0x98, 0x34, 0x18},
	{0xac, 0x50, 0x30},
	{0xc0, 0x68, 0x48},
	{0xd0, 0x80, 0x5c},
	{0xe0, 0x94, 0x70},
	{0xec, 0xa8, 0x80},
	{0xfc, 0xbc, 0x94},
	{0x88, 0x00, 0x00},
	{0x9c, 0x20, 0x20},
	{0xb0, 0x3c, 0x3c},
	{0xc0, 0x58, 0x58},
	{0xd0, 0x70, 0x70},
	{0xe0, 0x88, 0x88},
	{0xec, 0xa0, 0xa0},
	{0xfc, 0xb4, 0xb4},
	{0x78, 0x00, 0x5c},
	{0x8c, 0x20, 0x74},
	{0xa0, 0x3c, 0x88},
	{0xb0, 0x58, 0x9c},
	{0xc0, 0x70, 0xb0},
	{0xd0, 0x84, 0xc0},
	{0xdc, 0x9c, 0xd0},
	{0xec, 0xb0, 0xe0},
	{0x48, 0x00, 0x78},
	{0x60, 0x20, 0x90},
	{0x78, 0x3c, 0xa4},
	{0x8c, 0x58, 0xb8},
	{0xa0, 0x70, 0xcc},
	{0xb4, 0x84, 0xdc},
	{0xc4, 0x9c, 0xec},
	{0xd4, 0xb0, 0xfc},
	{0x14, 0x00, 0x84},
	{0x30, 0x20, 0x98},
	{0x4c, 0x3c, 0xac},
	{0x68, 0x58, 0xc0},
	{0x7c, 0x70, 0xd0},
	{0x94, 0x88, 0xe0},
	{0xa8, 0xa0, 0xec},
	{0xbc, 0xb4, 0xfc},
	{0x00, 0x00, 0x88},
	{0x1c, 0x20, 0x9c},
	{0x38, 0x40, 0xb0},
	{0x50, 0x5c, 0xc0},
	{0x68, 0x74, 0xd0},
	{0x7c, 0x8c, 0xe0},
	{0x90, 0xa4, 0xec},
	{0xa4, 0xb8, 0xfc},
	{0x00, 0x18, 0x7c},
	{0x1c, 0x38, 0x90},
	{0x38, 0x54, 0xa8},
	{0x50, 0x70, 0xbc},
	{0x68, 0x88, 0xcc},
	{0x7c, 0x9c, 0xdc},
	{0x90, 0xb4, 0xec},
	{0xa4, 0xc8, 0xfc},
	{0x00, 0x2c, 0x5c},
	{0x1c, 0x4c, 0x78},
	{0x38, 0x68, 0x90},
	{0x50, 0x84, 0xac},
	{0x68, 0x9c, 0xc0},
	{0x7c, 0xb4, 0xd4},
	{0x90, 0xcc, 0xe8},
	{0xa4, 0xe0, 0xfc},
	{0x00, 0x3c, 0x2c},
	{0x1c, 0x5c, 0x48},
	{0x38, 0x7c, 0x64},
	{0x50, 0x9c, 0x80},
	{0x68, 0xb4, 0x94},
	{0x7c, 0xd0, 0xac},
	{0x90, 0xe4, 0xc0},
	{0xa4, 0xfc, 0xd4},
	{0x00, 0x3c, 0x00},
	{0x20, 0x5c, 0x20},
	{0x40, 0x7c, 0x40},
	{0x5c, 0x9c, 0x5c},
	{0x74, 0xb4, 0x74},
	{0x8c, 0xd0, 0x8c},
	{0xa4, 0xe4, 0xa4},
	{0xb8, 0xfc, 0xb8},
	{0x14, 0x38, 0x00},
	{0x34, 0x5c, 0x1c},
	{0x50, 0x7c, 0x38},
	{0x6c, 0x98, 0x50},
	{0x84, 0xb4, 0x68},
	{0x9c, 0xcc, 0x7c},
	{0xb4, 0xe4, 0x90},
	{0xc8, 0xfc, 0xa4},
	{0x2c, 0x30, 0x00},
	{0x4c, 0x50, 0x1c},
	{0x68, 0x70, 0x34},
	{0x84, 0x8c, 0x4c},
	{0x9c, 0xa8, 0x64},
	{0xb4, 0xc0, 0x78},
	{0xcc, 0xd4, 0x88},
	{0xe0, 0xec, 0x9c},
	{0x44, 0x28, 0x00},
	{0x64, 0x48, 0x18},
	{0x84, 0x68, 0x30},
	{0xa0, 0x84, 0x44},
	{0xb8, 0x9c, 0x58},
	{0xd0, 0xb4, 0x6c},
	{0xe8, 0xcc, 0x7c},
	{0xfc, 0xe0, 0x8c},
};
	
#endif /* ntsc_palette_h */
