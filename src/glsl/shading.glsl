#version 430

#ifdef VERTEX_SHADER

in vec4 position;
out vec3 vertex_position;

void main( )
{
    vertex_position = position.xyz;
    gl_Position = position;
}
#endif

#ifdef GEOMETRY_SHADER

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in vec3 vertex_position[];
out vec3 geometry_position;
out vec3 geometry_normal;
out vec3 geometry_view;
out vec3 geometry_distance;
out vec3 geometry_color;

void main()
{
	vec3 pts[3];
	pts = vec3[3](( vertex_position[0] - 0.5 ) * u_scene_size, ( vertex_position[1] - 0.5 ) * u_scene_size, ( vertex_position[2] - 0.5 ) * u_scene_size);
	
	vec3 pts_abs[3];
	pts_abs = vec3[3](( vertex_position[0]) * u_scene_size, ( vertex_position[1]) * u_scene_size, ( vertex_position[2] ) * u_scene_size);

	vec4 transformed[3];
	transformed[0] = u_transforms.modelviewprojection * vec4(pts[0], 1 );
	transformed[1] = u_transforms.modelviewprojection * vec4(pts[1], 1 );
	transformed[2] = u_transforms.modelviewprojection * vec4(pts[2], 1 );
	
	vec2 p0 = u_viewport * transformed[0].xy / transformed[0].w;
	vec2 p1 = u_viewport * transformed[1].xy / transformed[1].w;
	vec2 p2 = u_viewport * transformed[2].xy / transformed[2].w;
	
	vec2 v[3] = vec2[3](p2 - p1, p2 - p0, p1 - p0);
	float area = abs (v[1].x*v[2].y - v[1].y*v[2].x);
	
	for(int i =0; i<3; i++)
	{
		geometry_distance = vec3(0);
		geometry_distance[i] = area * inversesqrt (dot (v[i],v[i]));
		gl_Position = transformed[i];
		geometry_position = vertex_position[i].xyz;
		geometry_view = (u_transforms.modelview * vec4( ((vertex_position[i]-0.5)*u_scene_size), 1 )).xyz;
		vec3 center = (pts_abs[1] + pts_abs[2] + pts_abs[0]) / 3;
		gl_PrimitiveID = int( length(center)*1000 );
		EmitVertex();
	}
	
	EndPrimitive();
}

#endif

#ifdef FRAGMENT_SHADER

layout(early_fragment_tests) in;

in vec3 geometry_position;
in vec3 geometry_distance;
in vec3 geometry_view;

out vec4 fragment_color;

uniform float u_curv_radius;
uniform float u_kmin;
uniform float u_kmax;

uniform int textured;
uniform int solid_wireframe;
uniform int u_ground_truth;

uniform sampler2D u_texcolor_x;
uniform sampler2D u_texcolor_y;
uniform sampler2D u_texcolor_z;

uniform sampler2D u_texbump_x;
uniform sampler2D u_texbump_y;
uniform sampler2D u_texbump_z;

uniform vec3 u_camera_pos;

float specular(vec3 n,vec3 l,vec3 e,float s) {    
    float nrm = (s + 8.0) / (3.1415 * 8.0);
    return pow(max(dot(normalize(reflect(e,n)),normalize(l)),0.0),s) * nrm;
}
float diffuse(vec3 n,vec3 l,float p) {
    return pow(clamp(dot(normalize(n),normalize(l)), 0.3, 1.0), p);
}

vec3 perturb_normal(vec3 surf_pos, vec3 normal, float h)
{
	vec3 sigmaS = dFdx(surf_pos);
	vec3 sigmaT = dFdy(surf_pos);
	vec3 vn = normal;
	
	vec3 vr1 = cross(sigmaT, vn);
	vec3 vr2 = cross(vn, sigmaS);
	
	float det = dot(sigmaS, vr1);
	
	float dBs = dFdx( h );
	float dBt = dFdy( h );
	
	vec3 grad = sign(det) * (dBs * vr1 + dBt * vr2);
	return normalize( abs(det)*vn - grad );
	
}

vec3 HSVtoRGB(vec3 hsv)
{
  int i;
  double f, p, q, t;
  if( hsv.y == 0 ) {                     // achromatic (gray)
    return vec3(hsv.z);
  }
  i = int( floor( hsv.x / 60 ) );
  f = ( hsv.x / 60 ) - i;                        // factorial part of h
  p = hsv.z * ( 1.0 - hsv.y );
  q = hsv.z * ( 1.0 - hsv.y * f );
  t = hsv.z * ( 1.0 - hsv.y * ( 1.0 - f ) );

  if (i==0)
  	return vec3(hsv.z, t, p);
  if (i==1)
  	return vec3(q, hsv.z, p);
  if (i==2)
  	return vec3(p, hsv.z, t);
  if (i==3)
  	return vec3(p, q, hsv.z);
  if (i==4)
  	return vec3(t, p, hsv.z);

  return vec3(hsv.z, p, q);
}

vec3 colormap(float scale)
{
  float cycles = 1;
  const double hue = 360 * ( scale * cycles - floor(scale * cycles));
  return HSVtoRGB( vec3(hue, 0.9, 1.0) );
}

void main( )
{

	vec3 geometry_normal = -1 * normalize(cross( dFdx(geometry_position.xyz), dFdy(geometry_position.xyz)));

	float r = u_curv_radius;
	vec3 color;

	/*curvature from regular integration*/

	if (u_ground_truth == 4)
	{
		float volume = 0.0;
		float gt_curvature = 0.0;
		float approx_curvature = 0.0;
		float vol_boule = ((4*3.14159*(r*r*r))/3.0);

		float size_obj = u_size_tex;
		for(float i=-r; i<r; i++)
		for(float j=-r; j<r; j++)
		for(float k=-r; k<r; k++)
		{
			vec3 probe = vec3(i+0.5, j+0.5, k+0.5);
			if (length(probe) <= r)
			{
				volume += textureLod(densities, geometry_position + (probe/size_obj), 0).r;
			}
		}

		//Curvature from volume
		float fact83r = 8.0/(3.0*r);
		float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
		
		float curvature = fact83r - fact4pir4*volume;

		gt_curvature = curvature;
		if(u_kmax > u_kmin)
			gt_curvature = (curvature-u_kmin) / (u_kmax-u_kmin);

		float density = textureLod(densities, geometry_position, log2(r)).r;
		volume =  vol_boule * density;
		//volume =  (r*r*r) * density;
		
		curvature = fact83r - fact4pir4*volume;

		approx_curvature = curvature;
		if(u_kmax > u_kmin)
			approx_curvature = (curvature-u_kmin) / (u_kmax-u_kmin);

		float diff = length(gt_curvature - approx_curvature);
		float mind = -0.1;
		float maxd = 0.1;
		diff = (diff + mind) / (maxd - mind);
		color= diff * vec3(1, 0, 0) + (1- diff)*vec3(0, 0, 1);
	}
	else if (u_ground_truth == 1)
	{
		float volume = 0.0;
		float gt_curvature = 0.0;
		
		float size_obj = u_size_tex;
		for(float i=-r; i<r; i++)
		for(float j=-r; j<r; j++)
		for(float k=-r; k<r; k++)
		{
			vec3 probe = vec3(i+0.5, j+0.5, k+0.5);
			if (length(probe) <= r)
			{
				volume += textureLod(densities, geometry_position + (probe/size_obj), 0).r;
			}
		}

		//Curvature from volume
		float fact83r = 8.0/(3.0*r);
		float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
		
		float curvature = fact83r - fact4pir4*volume;

		gt_curvature = curvature;
		if(u_kmax > u_kmin)
			gt_curvature = (curvature-u_kmin) / (u_kmax-u_kmin);

		if ((gt_curvature<0) || (gt_curvature>1)) color= vec3(0.5,0.5,0.5);
		else
		  color= colormap(gt_curvature);

	}
	else if (u_ground_truth == 2)
	{
		float volume = 0.0;
		float gt_curvature = 0.0;
		float size_obj = u_size_tex;

		float higher_level = log2(sqrt(2.0)/2.0*r);
		//volume = higher_level;
  		//volume = textureLod(densities, geometry_position, higher_level).r;
  		
		//Curvature from volume
		float fact83r = 8.0/(3.0*r);
		float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
		
		float curvature = fact83r - fact4pir4*volume;

		gt_curvature = curvature;
		if(u_kmax > u_kmin)
			gt_curvature = (curvature-u_kmin) / (u_kmax-u_kmin);

		if ((gt_curvature<0) || (gt_curvature>1)) color= vec3(0.5,0.5,0.5);
		else
		  color= colormap(gt_curvature);
	}
	else if (u_ground_truth == 3) /*curvature from O(1) probing*/
	{
		float volume = 0.0;
		float approx_curvature = 0.0;
		float vol_boule = ((4*3.14159*(r*r*r))/3.0);

		float density = textureLod(densities, geometry_position, log2(r)).r;
		volume =  ((4*3.14159*(r*r*r))/3.0) * density;
		//volume =  (r*r*r) * density;

		float fact83r = 8.0/(3.0*r);
		float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
		
		float curvature = fact83r - fact4pir4*volume;

		approx_curvature = curvature;
		if(u_kmax > u_kmin)
			approx_curvature = (curvature-u_kmin) / (u_kmax-u_kmin);

		if ((approx_curvature<0) || (approx_curvature>1)) color= vec3(0.5,0.5,0.5);
		else
		  color= colormap(approx_curvature);
	}

	
	//Phong
	float shadow_weight = 0.3;
	float dotnormal = abs(dot(normalize(geometry_normal), vec3(-1, -1, -1)));
	fragment_color = vec4( shadow_weight * color * dotnormal + (1-shadow_weight) * color, 1);

	if (solid_wireframe == 1)
	{
		const float wirescale = 0.5; // scale of the wire
		vec3 d2 = geometry_distance * geometry_distance;
		float nearest = min (min (d2.x, d2.y), d2.z);
		float f = exp2 (-nearest / wirescale);
		fragment_color = mix (fragment_color, vec4(0), f);
	}
}
#endif
