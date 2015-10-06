/*
#ifdef VERTEX_SHADER

in vec4 position;

uniform float u_curv_radius;
uniform float u_size_tex;
uniform sampler3D densities;
uniform sampler3D u_xyz2_tex;
uniform sampler3D u_xy_yz_xz_tex;

out vec3 vertex_position;
out vec3 vertex_color;

out float curv_value;
out vec3 curv_dir_min;
out vec3 curv_dir_max;

mat3 fromSymToMatrix(vec3 sym)
{
	vec3 m0 = vec3(0);
	m0[int(abs(sym[0])-1)] = 1;
	if (sym[0] < 0)
		m0[int(abs(sym[0])-1)] = -1;
	
	vec3 m1 = vec3(0);
	m1[int(abs(sym[1])-1)] = 1;
	if (sym[1] < 0)
		m1[int(abs(sym[1])-1)] = -1;
		
	vec3 m2 = vec3(0);
	m2[int(abs(sym[2])-1)] = 1;
	if (sym[2] < 0)
		m2[int(abs(sym[2])-1)] = -1;
	
	mat3 ret;
	ret[0] = vec3(m0.x, m1.x, m2.x);
	ret[1] = vec3(m0.y, m1.y, m2.y);
	ret[2] = vec3(m0.z, m1.z, m2.z);
	return ret;
}

void main( )
{
    vertex_position = position.xyz;

    float r = u_curv_radius;
	vec3 color;
	float vol_boule = ((4*3.14159*(r*r*r))/3.0);
	
	float volume = 0.0;
	float gt_curvature = 0.0;
	float size_obj = u_size_tex;

	vec3 symetries[24];
	int id = 0;
	for(int i=1; i<=3; i++)
	{
		for(int j=1; j<=3; j++)
		{
			if(j==i)
				continue;
			for(int k=1; k<=3; k++)
			{
				if (k==i || k== j || j > k)
					continue;
				
				for(int s0=1; s0>=-1; s0-=2)
				for(int s1=1; s1>=-1; s1-=2)
				for(int s2=1; s2>=-1; s2-=2)
					symetries[id++]=vec3(s0*i, s1*j, s2*k);
			}
		}
	}
	
	vec3 orig = vertex_position*u_size_tex;

	float k = log2((2.0*r/sqrt(3)));
	float size = pow(2.0, k);
	
	float total_volume = 0.0;
	
	volume += textureLod(densities, orig/u_size_tex, k).r * pow(size, 3);
	total_volume += pow(size, 3);

	vec3 center = orig + vec3(size/2.0, 0, 0);
	while(k>=1)
	{
		size/=2.0;
		
		vec3 right_corner = center+vec3(size);
		
		vec3 current_voxel = right_corner;
		bool stay = true;
		while(true)
		{
			if (length(current_voxel - orig) > r)
				break;
			
			while(true)
			{
				if (length(current_voxel - orig) > r)
					break;
				
				for(int i=0; i<24; i++)
				{
					stay = false;
					vec3 pos = orig + fromSymToMatrix(symetries[i])*(current_voxel-vec3(size/2.0));
					volume += textureLod(densities, pos/u_size_tex, k).r * pow(size, 3);
					total_volume += pow(size, 3);
				}
				current_voxel+= vec3(0, size, 0);
			}
			current_voxel.y = right_corner.y;
			current_voxel += vec3(0, 0, size);
		}
		
		if(!stay)
			center += vec3(size, 0, 0);
		
		k--;
	}
	
	volume *= vol_boule/total_volume;
	
	//Curvature from volume
	float fact83r = 8.0/(3.0*r);
	float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
	
	float curvature = fact83r - fact4pir4*volume;
	
	curv_value = curvature;
	curv_dir_max = vec3(0, 0, 1);
	curv_dir_min = vec3(1, 0, 1);
	
    gl_Position = position;
}
#endif

#ifdef GEOMETRY_SHADER

#define TRANSFORMS_BINDING 0

layout (triangles) in;
layout (triangle_strip, max_vertices = 50) out;

uniform int u_curv_dir;

in vec3 vertex_position[];
in vec3 vertex_color[];
in vec3 curv_dir_max[];
in vec3 curv_dir_min[];
in float curv_value[];

out vec3 geometry_position;
out vec3 geometry_normal;
out vec3 geometry_view;
out vec3 geometry_distance;
out vec3 geometry_color;
out float geometry_curv_value;
out flat int geometry_curvdir;

layout (std140, binding = TRANSFORMS_BINDING)
uniform Transforms {
	mat4 modelview;
	mat4 projection;
	mat4 modelviewprojection;
	mat4 invmodelview;
} u_transforms;

uniform vec3 u_scene_size;
uniform vec2 u_viewport;

void setPoint(vec3 point, vec3 color)
{
	geometry_curvdir = 1;
	gl_Position = u_transforms.modelviewprojection * vec4(point, 1 );
	geometry_position = point.xyz;
	geometry_color = color;
}

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
		geometry_color = vertex_color[i];
		geometry_curv_value = curv_value[i];
		EmitVertex();
	}
	
	EndPrimitive();
	
	if (u_curv_dir == 1)
	{
		vec3 mean_dir = (curv_dir_min[0]+curv_dir_min[1]+curv_dir_min[2]);
		mean_dir = normalize(mean_dir);
		vec3 center_face = (pts[0].xyz+pts[1].xyz+pts[2].xyz)/3.0;
		vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, 
							normalize(pts[0]-pts[2]).xyz));
		vec3 tan_dir = normalize(cross(normalize(normale), normalize(mean_dir)));
		vec3 depth = normalize(cross(normalize(tan_dir), normalize(mean_dir)));
		
		float l = 2.0;
		float L = 16.0;
		float p = 1.0;
		
		vec3 middle_geom = center_face + normale;
		vec3 up_geom = middle_geom+mean_dir*0.5*L;
		vec3 bottom_geom = middle_geom-mean_dir*0.5*L;
		vec3 right_geom = middle_geom+tan_dir*0.5*l;
		vec3 left_geom = middle_geom-tan_dir*0.5*l;
		
		vec3 c0 = (right_geom+up_geom)/2.0;
		vec3 c1 = (left_geom+up_geom)/2.0;
		vec3 c2 = (right_geom+bottom_geom)/2.0;
		vec3 c3 = (left_geom+bottom_geom)/2.0;
		
		vec3 c4 = c0+p*depth;
		vec3 c5 = c1+p*depth;
		vec3 c6 = c2+p*depth;
		vec3 c7 = c3+p*depth;
		
		vec3 shade = vec3(0, 0, 1);
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		setPoint(c3, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c5, shade);
		EmitVertex();
		setPoint(c4, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c6, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		
		setPoint(c4, shade);
		EmitVertex();
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		
		
		EndPrimitive();
	}
	
	if (u_curv_dir == 2)
	{
		vec3 mean_dir = (curv_dir_max[0]+curv_dir_max[1]+curv_dir_max[2]);
		mean_dir = normalize(mean_dir);
		vec3 center_face = (pts[0].xyz+pts[1].xyz+pts[2].xyz)/3.0;
		vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, 
							normalize(pts[0]-pts[2]).xyz));
		vec3 tan_dir = normalize(cross(normalize(normale), normalize(mean_dir)));
		vec3 depth = normalize(cross(normalize(tan_dir), normalize(mean_dir)));
		
		float l = 2.0;
		float L = 16.0;
		float p = 1.0;
		
		vec3 middle_geom = center_face + normale;
		vec3 up_geom = middle_geom+mean_dir*0.5*L;
		vec3 bottom_geom = middle_geom-mean_dir*0.5*L;
		vec3 right_geom = middle_geom+tan_dir*0.5*l;
		vec3 left_geom = middle_geom-tan_dir*0.5*l;
		
		vec3 c0 = (right_geom+up_geom)/2.0;
		vec3 c1 = (left_geom+up_geom)/2.0;
		vec3 c2 = (right_geom+bottom_geom)/2.0;
		vec3 c3 = (left_geom+bottom_geom)/2.0;
		
		vec3 c4 = c0+p*depth;
		vec3 c5 = c1+p*depth;
		vec3 c6 = c2+p*depth;
		vec3 c7 = c3+p*depth;
		
		vec3 shade = vec3(1, 0, 0);
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		setPoint(c3, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c5, shade);
		EmitVertex();
		setPoint(c4, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c6, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		
		setPoint(c4, shade);
		EmitVertex();
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		
		
		EndPrimitive();
	}
}

#endif

#ifdef FRAGMENT_SHADER

layout(early_fragment_tests) in;

in vec3 geometry_position;
in vec3 geometry_distance;
in vec3 geometry_view;
in float geometry_curv_value;
in vec3 geometry_color;
in flat int geometry_curvdir;

uniform float u_kmin;
uniform float u_kmax;
uniform int solid_wireframe;
uniform vec3 u_camera_pos;

out vec4 fragment_color;

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

vec3 colorFromCurv(float c)
{
	vec3 color;
	float gt_curvature = c;
	if(u_kmax > u_kmin)
		gt_curvature = (c-u_kmin) / (u_kmax-u_kmin);

	if ((gt_curvature<0) || (gt_curvature>1)) color= vec3(0.5,0.5,0.5);
	else
		color= colormap(gt_curvature);
	
	return color;
}

void main( )
{
	vec3 geometry_normal = -1 * normalize(cross( dFdx(geometry_position.xyz), dFdy(geometry_position.xyz)));
	vec3 color;
	if (geometry_curvdir == 0)
		color = colorFromCurv(geometry_curv_value);
	else
		color = geometry_color;
	
	//Phong
	float shadow_weight = 0.5;
	float dotnormal = abs(dot(normalize(geometry_normal), vec3(-1, -1, -1)));
	fragment_color = vec4( shadow_weight * color * dotnormal + (1-shadow_weight) * color, 1);

	if (geometry_curvdir == 0 && solid_wireframe == 1)
	{
		const float wirescale = 0.5; // scale of the wire
		vec3 d2 = geometry_distance * geometry_distance;
		float nearest = min (min (d2.x, d2.y), d2.z);
		float f = exp2 (-nearest / wirescale);
		fragment_color = mix (fragment_color, vec4(0), f);
	}
}
#endif*/

#version 430

#ifdef VERTEX_SHADER

in vec4 position;

uniform float u_curv_radius;
uniform float u_size_tex;
uniform sampler3D densities;
uniform sampler3D u_xyz2_tex;
uniform sampler3D u_xy_yz_xz_tex;
uniform sampler3D u_xyz_tex;

out vec3 vertex_position;
out vec3 vertex_color;

out float curv_value;
out vec3 curv_dir_min;
out vec3 curv_dir_max;
out vec3 curv_normale;

uniform vec3 u_scene_size;

mat3 fromSymToMatrix(vec3 sym)
{
	vec3 m0 = vec3(0);
	m0[int(abs(sym[0])-1)] = 1;
	if (sym[0] < 0)
		m0[int(abs(sym[0])-1)] = -1;
	
	vec3 m1 = vec3(0);
	m1[int(abs(sym[1])-1)] = 1;
	if (sym[1] < 0)
		m1[int(abs(sym[1])-1)] = -1;
		
	vec3 m2 = vec3(0);
	m2[int(abs(sym[2])-1)] = 1;
	if (sym[2] < 0)
		m2[int(abs(sym[2])-1)] = -1;
	
	mat3 ret;
	ret[0] = vec3(m0.x, m1.x, m2.x);
	ret[1] = vec3(m0.y, m1.y, m2.y);
	ret[2] = vec3(m0.z, m1.z, m2.z);
	return ret;
}

void main( )
{
    vertex_position = position.xyz;

    float r = u_curv_radius;
	vec3 color;
	float vol_boule = ((4*3.14159*(r*r*r))/3.0);

	/*curvature from regular integration*/
	float volume = 0.0;
	
	vec3 symetries[24];
	int id = 0;
	for(int i=1; i<=3; i++)
	{
		for(int j=1; j<=3; j++)
		{
			if(j==i)
				continue;
			for(int k=1; k<=3; k++)
			{
				if (k==i || k== j || j > k)
					continue;
				
				for(int s0=1; s0>=-1; s0-=2)
				for(int s1=1; s1>=-1; s1-=2)
				for(int s2=1; s2>=-1; s2-=2)
					symetries[id++]=vec3(s0*i, s1*j, s2*k);
			}
		}
	}
	
	vec3 orig = vertex_position*u_size_tex;

	float k = log2((2.0*r/sqrt(3)));
	float size = pow(2.0, k);
	
	float total_volume = 0.0;
	
	volume += textureLod(densities, orig/u_size_tex, k).r * pow(size, 3);
	total_volume += pow(size, 3);

	vec3 center = orig + vec3(size/2.0, 0, 0);
	while(k>=1)
	{
		size/=2.0;
		
		vec3 right_corner = center+vec3(size);
		
		vec3 current_voxel = right_corner;
		bool stay = true;
		while(true)
		{
			if (length(current_voxel - orig) > r)
				break;
			
			while(true)
			{
				if (length(current_voxel - orig) > r)
					break;
				
				for(int i=0; i<24; i++)
				{
					stay = false;
					vec3 pos = orig + fromSymToMatrix(symetries[i])*(current_voxel-vec3(size/2.0));
					volume += textureLod(densities, pos/u_size_tex, k).r * pow(size, 3);
					total_volume += pow(size, 3);
				}
				current_voxel+= vec3(0, size, 0);
			}
			current_voxel.y = right_corner.y;
			current_voxel += vec3(0, 0, size);
		}
		
		if(!stay)
			center += vec3(size, 0, 0);
		
		k--;
	}
	
	volume *= vol_boule/total_volume;
	
	float fact83r = 8.0/(3.0*r);
	float fact4pir4 = 4.0 / (3.14159*r*r*r*r);
	
	float curvature = fact83r - fact4pir4*volume;
	
	curv_value = curvature;
	curv_dir_max = vec3(0, 0, 1);
	curv_dir_min = vec3(1, 0, 1);
	
    gl_Position = position;
}
#endif

#ifdef GEOMETRY_SHADER

#define TRANSFORMS_BINDING 0

layout (triangles) in;
layout (triangle_strip, max_vertices = 50) out;

uniform int u_curv_dir;

in vec3 vertex_position[];
in vec3 vertex_color[];
in vec3 curv_dir_max[];
in vec3 curv_dir_min[];
in vec3 curv_normale[];
in float curv_value[];

out vec3 geometry_position;
out vec3 geometry_normal;
out vec3 geometry_view;
out vec3 geometry_distance;
out vec3 geometry_color;
out float geometry_curv_value;
out flat int geometry_curvdir;

layout (std140, binding = TRANSFORMS_BINDING)
uniform Transforms {
	mat4 modelview;
	mat4 projection;
	mat4 modelviewprojection;
	mat4 invmodelview;
} u_transforms;

uniform vec3 u_scene_size;
uniform vec2 u_viewport;

void setPoint(vec3 point, vec3 color)
{
	geometry_curvdir = 1;
	gl_Position = u_transforms.modelviewprojection * vec4(point, 1 );
	geometry_position = point.xyz;
	geometry_color = color;
}

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
		geometry_color = vertex_color[i];
		geometry_curv_value = curv_value[i];
		geometry_curvdir = 0;
		EmitVertex();
	}
	
	EndPrimitive();
	
	if (u_curv_dir == 1)
	{
		vec3 mean_dir = (curv_dir_min[0]+curv_dir_min[1]+curv_dir_min[2]);
		mean_dir = normalize(mean_dir);
		vec3 center_face = (pts[0].xyz+pts[1].xyz+pts[2].xyz)/3.0;
		vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, 
							normalize(pts[0]-pts[2]).xyz));
		vec3 tan_dir = normalize(cross(normalize(normale), normalize(mean_dir)));
		vec3 depth = normalize(cross(normalize(tan_dir), normalize(mean_dir)));
		
		float l = 2.0;
		float L = 16.0;
		float p = 1.0;
		
		vec3 middle_geom = center_face + normale;
		vec3 up_geom = middle_geom+mean_dir*0.5*L;
		vec3 bottom_geom = middle_geom-mean_dir*0.5*L;
		vec3 right_geom = middle_geom+tan_dir*0.5*l;
		vec3 left_geom = middle_geom-tan_dir*0.5*l;
		
		vec3 c0 = (right_geom+up_geom)/2.0;
		vec3 c1 = (left_geom+up_geom)/2.0;
		vec3 c2 = (right_geom+bottom_geom)/2.0;
		vec3 c3 = (left_geom+bottom_geom)/2.0;
		
		vec3 c4 = c0+p*depth;
		vec3 c5 = c1+p*depth;
		vec3 c6 = c2+p*depth;
		vec3 c7 = c3+p*depth;
		
		vec3 shade = vec3(0, 0, 1);
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		setPoint(c3, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c5, shade);
		EmitVertex();
		setPoint(c4, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c6, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		
		setPoint(c4, shade);
		EmitVertex();
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		
		
		EndPrimitive();
	}
	
	if (u_curv_dir == 2)
	{
		vec3 mean_dir = (curv_dir_max[0]+curv_dir_max[1]+curv_dir_max[2]);
		mean_dir = normalize(mean_dir);
		vec3 center_face = (pts[0].xyz+pts[1].xyz+pts[2].xyz)/3.0;
		vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, 
							normalize(pts[0]-pts[2]).xyz));
		vec3 tan_dir = normalize(cross(normalize(normale), normalize(mean_dir)));
		vec3 depth = normalize(cross(normalize(tan_dir), normalize(mean_dir)));
		
		float l = 2.0;
		float L = 16.0;
		float p = 1.0;
		
		vec3 middle_geom = center_face + normale;
		vec3 up_geom = middle_geom+mean_dir*0.5*L;
		vec3 bottom_geom = middle_geom-mean_dir*0.5*L;
		vec3 right_geom = middle_geom+tan_dir*0.5*l;
		vec3 left_geom = middle_geom-tan_dir*0.5*l;
		
		vec3 c0 = (right_geom+up_geom)/2.0;
		vec3 c1 = (left_geom+up_geom)/2.0;
		vec3 c2 = (right_geom+bottom_geom)/2.0;
		vec3 c3 = (left_geom+bottom_geom)/2.0;
		
		vec3 c4 = c0+p*depth;
		vec3 c5 = c1+p*depth;
		vec3 c6 = c2+p*depth;
		vec3 c7 = c3+p*depth;
		
		vec3 shade = vec3(1, 0, 0);
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		setPoint(c3, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		setPoint(c5, shade);
		EmitVertex();
		setPoint(c4, shade);
		EmitVertex();
		
		setPoint(c7, shade);
		EmitVertex();
		setPoint(c6, shade);
		EmitVertex();
		setPoint(c2, shade);
		EmitVertex();
		
		setPoint(c4, shade);
		EmitVertex();
		setPoint(c0, shade);
		EmitVertex();
		setPoint(c1, shade);
		EmitVertex();
		
		
		EndPrimitive();
	}
}

#endif

#ifdef FRAGMENT_SHADER

layout(early_fragment_tests) in;

in vec3 geometry_position;
in vec3 geometry_distance;
in vec3 geometry_view;
in float geometry_curv_value;
in vec3 geometry_color;
in flat int geometry_curvdir;

uniform float u_kmin;
uniform float u_kmax;
uniform int solid_wireframe;
uniform vec3 u_camera_pos;

out vec4 fragment_color;

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

vec3 colorFromCurv(float c)
{
	vec3 color;
	float gt_curvature = c;
	if(u_kmax > u_kmin)
		gt_curvature = (c-u_kmin) / (u_kmax-u_kmin);

	if ((gt_curvature<0) || (gt_curvature>1)) color= vec3(0.5,0.5,0.5);
	else
		color= colormap(gt_curvature);
	
	return color;
}

void main( )
{
	vec3 geometry_normal = -1 * normalize(cross( dFdx(geometry_position.xyz), dFdy(geometry_position.xyz)));
	vec3 color;
	if (geometry_curvdir == 0)
		color = colorFromCurv(geometry_curv_value);
	else
		color = abs(geometry_color);
	
	//Phong
	float shadow_weight = 0.5;
	float dotnormal = abs(dot(normalize(geometry_normal), vec3(-1, -1, -1)));
	fragment_color = vec4(color, 1);//vec4( shadow_weight * color * dotnormal + (1-shadow_weight) * color, 1);

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