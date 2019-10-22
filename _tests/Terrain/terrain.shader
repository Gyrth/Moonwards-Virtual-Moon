shader_type spatial;
//render_mode unshaded, cull_disabled;

uniform sampler2D splatmap;
uniform sampler2D texture0 : hint_albedo;
uniform sampler2D normal_tex0 : hint_normal;
uniform sampler2D texture1 : hint_albedo;
uniform sampler2D normal_tex1 : hint_normal;
uniform sampler2D texture2 : hint_albedo;
uniform sampler2D normal_tex2 : hint_normal;
uniform sampler2D noise_texture;

uniform sampler2D albedo_tex : hint_albedo;
uniform sampler2D normal_tex : hint_normal;

uniform float tex0_scale = 1;
uniform float tex1_scale = 1;
uniform float tex2_scale = 1;

uniform float offset : hint_range(0, 10);
uniform float normal_depth : hint_range(0, 1);

uniform float blend : hint_range(0, 1);

float sum( vec3 v ) { return v.x+v.y+v.z; }

vec3 textureNoTile(in sampler2D map, in vec2 x, float v)
{
	float k = texture(noise_texture, 0.005 * x).x; // cheap (cache friendly) lookup
	
	vec2 duvdx = dFdx( x );
	vec2 duvdy = dFdx( x );
	
	float l = k*8.0;
	float f = fract(l);
	float ia;
	float ib;
	
	ia = floor(l); // my method
	ib = ia + 1.0;
	
	vec2 offa = sin(vec2(3.0,7.0)*ia); // can replace with any other hash
	vec2 offb = sin(vec2(3.0,7.0)*ib); // can replace with any other hash
	
	vec3 cola = textureGrad( map, x + v*offa, duvdx, duvdy ).xyz;
	vec3 colb = textureGrad( map, x + v*offb, duvdx, duvdy ).xyz;
	
	return mix( cola, colb, smoothstep(0.2,0.8,f-0.1*sum(cola-colb)) );
}

void fragment() { 
	vec3 color0;
	vec3 normal0;
	vec3 color1;
	vec3 normal1;
	vec3 color2;
	vec3 normal2;
	vec3 normal;
	vec3 albedo;
	vec4 splatmapcolor;
	
	splatmapcolor = texture(splatmap, UV);
	color0 = textureNoTile(texture0, UV * tex0_scale, offset) * splatmapcolor.r;
	normal0 = textureNoTile(normal_tex0, UV * tex0_scale, offset) * splatmapcolor.r;
	
	color1 = textureNoTile(texture1, UV * tex1_scale, offset) * splatmapcolor.g;
	normal1 = textureNoTile(normal_tex1, UV * tex1_scale, offset) * splatmapcolor.g;
	
	color2 = textureNoTile(texture2, UV * tex2_scale, offset) * splatmapcolor.b;
	normal2 = textureNoTile(normal_tex2, UV * tex2_scale, offset) * splatmapcolor.b;

	normal = (texture(normal_tex, UV).rgb * max(0.0, (1.0 - splatmapcolor.r - splatmapcolor.g - splatmapcolor.b)));
	normal = normal + (blend * (normal0 + normal1 + normal2));
	NORMALMAP = normal;
	
	//Either this one.
	albedo = (texture(albedo_tex, UV).rgb * max(0.0, (1.0 - splatmapcolor.r - splatmapcolor.g - splatmapcolor.b)));
	//Or this one.
//	albedo = texture(albedo_tex, UV).rgb;
	
	albedo = mix(albedo, (color0 + color1 + color2), blend);
	ALBEDO = albedo;
	NORMALMAP_DEPTH = normal_depth;
}