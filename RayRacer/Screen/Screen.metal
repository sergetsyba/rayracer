//
//  Screen.metal
//  RayRacer
//
//  Created by Serge Tsyba on 18.8.2024.
//

#include "ntsc_palette.h"
#include "field.h"

#include <metal_stdlib>

using namespace metal;

typedef struct {
	float4 vertex_position [[position]];
	float2 texture_position;
}  screen_vertex;

vertex screen_vertex make_vertex(uint vid [[vertex_id]]) {
	// generates [0, 0], [2, 0], [0, 2]
	const float2 texture_position = float2((vid << 1) & 2, vid & 2);
	// generates [-1, 0], [3, 1], [-1, 3]
	const float2 vertex_position = texture_position * float2(2.0, -2.0) + float2(-1.0, 1.0);

	// resulting vertext extends past rendered coordinate range
	// and is clipped
	return { float4(vertex_position, 0.0, 1.0), texture_position };
}

fragment float4 shade_fragment(screen_vertex in [[stage_in]],
							   device const uint8_t *data [[buffer(0)]],
							   constant field_geometry &geometry [[buffer(1)]]) {

	const uint2 position = uint2(in.texture_position * float2(geometry.image_size)) + geometry.image_origin;
	const uint data_index = position.y * geometry.field_size.x + position.x;

	// TIA color values are in the 7 most significant bits
	const uint color_index = data[data_index] >> 1;
	return ntsc_palette[color_index];
}
