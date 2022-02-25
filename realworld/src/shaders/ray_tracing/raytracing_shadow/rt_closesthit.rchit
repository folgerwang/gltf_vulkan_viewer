#version 460
#include "..\..\global_definition.glsl.h"

#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_shader_16bit_storage : enable

layout(location = 0) rayPayloadInEXT vec3 hitValue;
layout(location = 2) rayPayloadEXT bool shadowed;
hitAttributeEXT vec2 attribs;

layout(binding = 0, set = 0) uniform accelerationStructureEXT topLevelAS;
layout(binding = 2, set = 0) uniform UBO 
{
	mat4 viewInverse;
	mat4 projInverse;
	vec4 lightPos;
	int vertexSize;
} ubo;

layout(binding = 3, set = 0) buffer Vertices { float v[]; } vertices;
layout(binding = 4, set = 0) buffer Indices { uint16_t i[]; } indices;
layout(binding = 5, set = 0) buffer Geometries { VertexBufferInfo info[]; } geometries;

struct Vertex
{
  vec3 pos;
  vec3 normal;
  vec2 uv;
  vec4 color;
  vec4 _pad0;
  vec4 _pad1;
 };

Vertex unpack(uint index)
{
	// Unpack the vertices from the SSBO using the glTF vertex structure
	// The multiplier is the size of the vertex divided by four float components (=16 bytes)
	const int m = ubo.vertexSize / 16;

	float d0 = vertices.v[index + 0];
	float d1 = vertices.v[index + 1];
	float d2 = vertices.v[index + 2];

	Vertex v;
	v.pos = vec3(d0, d1, d2);//d0.xyz;
	v.normal = vec3(0, 0, 0);//vec3(d0.w, d1.x, d1.y);
	v.color = vec4(0.5, 0.5, 0.5, 1.0);//vec4(d2.x, d2.y, d2.z, 1.0);

	return v;
}

void main()
{
	VertexBufferInfo geom_info = geometries.info[gl_GeometryIndexEXT];
	uint base_idx = geom_info.index_offset + 3 * gl_PrimitiveID;

	ivec3 index = ivec3(indices.i[base_idx], indices.i[base_idx + 1], indices.i[base_idx + 2]) + ivec3(geom_info.position_offset);

	Vertex v0 = unpack(index.x);
	Vertex v1 = unpack(index.y);
	Vertex v2 = unpack(index.z);

	// Interpolate normal
	const vec3 barycentricCoords = vec3(1.0f - attribs.x - attribs.y, attribs.x, attribs.y);
	vec3 normal = normalize(v0.normal * barycentricCoords.x + v1.normal * barycentricCoords.y + v2.normal * barycentricCoords.z);

	// Basic lighting
	vec3 lightVector = normalize(ubo.lightPos.xyz);
	float dot_product = max(dot(lightVector, normal), 0.2);
	hitValue = v0.color.rgb * dot_product;
 
	// Shadow casting
	float tmin = 0.001;
	float tmax = 10000.0;
	vec3 origin = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	shadowed = true;  
	// Trace shadow ray and offset indices to match shadow hit/miss shader group indices
	traceRayEXT(topLevelAS, gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, 0xFF, 1, 0, 1, origin, tmin, lightVector, tmax, 2);
	if (shadowed) {
		hitValue *= 0.3;
	}

	hitValue = vec3(1, 0, 0);
}
