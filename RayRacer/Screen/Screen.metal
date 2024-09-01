//
//  Screen.metal
//  RayRacer
//
//  Created by Serge Tsyba on 18.8.2024.
//

#include <metal_stdlib>
#include "ntsc_palette.h"

using namespace metal;

typedef struct {
	float4 vertex_position [[position]];
	float2 texture_position;
}  screen_vertex;

constant screen_vertex vertices[] = {
	{{-1, -1, 0, 1}, {0, 1}},
	{{-1,  1, 0, 1}, {0, 0}},
	{{ 1,  1, 0, 1}, {1, 0}},
	{{-1, -1, 0, 1}, {0, 1}},
	{{ 1,  1, 0, 1}, {1, 0}},
	{{ 1, -1, 0, 1}, {1, 1}}
};

vertex screen_vertex make_vertex(uint vid [[vertex_id]]) {
	return vertices[vid];
}

fragment float4 shade_fragment(screen_vertex in [[stage_in]], texture2d<uint> texture [[texture(0)]]) {
	constexpr sampler noSampler;
	const auto color_index = texture.sample(noSampler, in.texture_position);
	
	// TIA color values are in the 7 most significant bits
	const auto color = float3(ntsc_palette[color_index.x / 2]);
	return float4(color / 255.0, 1.0);
}
