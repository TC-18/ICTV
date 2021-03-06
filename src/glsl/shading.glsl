/*
 * Copyright 2015 
 * Hélène Perrier <helene.perrier@liris.cnrs.fr>
 * Jérémy Levallois <jeremy.levallois@liris.cnrs.fr>
 * David Coeurjolly <david.coeurjolly@liris.cnrs.fr>
 * Jacques-Olivier Lachaud <jacques-olivier.lachaud@univ-savoie.fr>
 * Jean-Philippe Farrugia <jean-philippe.farrugia@liris.cnrs.fr>
 * Jean-Claude Iehl <jean-claude.iehl@liris.cnrs.fr>
 * 
 * This file is part of ICTV.
 * 
 * ICTV is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * ICTV is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with ICTV.  If not, see <http://www.gnu.org/licenses/>
 */

#version 430

#ifdef VERTEX_SHADER



layout (location = 0) in vec4 position;
//layout (location = 1) in vec3 k1k2;
layout (location = 1) in vec4 mindir;
layout (location = 2) in vec4 maxdir;
layout (location = 3) in vec4 normale;

out vec3 vertex_position;
out vec3 vertex_color;
out float curv_value;
out vec3 curv_dir_min;
out vec3 curv_dir_max;
out vec3 curv_normale;
out vec3 eigenvalues;
out vec3 covmatDiag;
out vec3 covmatUpper;
out vec3 vertex_k1_k2;

/*
uniform vec3 u_scene_size;
uniform float u_lvl;
uniform float u_curv_radius;
uniform float u_size_tex;
uniform sampler3D densities;
uniform sampler3D u_xyz2_tex;
uniform sampler3D u_xy_yz_xz_tex;
uniform sampler3D u_xyz_tex;
*/

uniform int u_curv_val;

void main( )
{
    vertex_position = position.xyz;
	vertex_color = vec3(1);
	//textureLod(u_xyz_tex, position.xyz, 2).rgb / (64.0*67.0);
	//vertex_color = position.xyz;

    curv_dir_min = mindir.xyz;
	curv_dir_max = maxdir.xyz;
	curv_normale = normale.xyz;

	vertex_k1_k2 = vec3(position.w, mindir.w, maxdir.w);

	float k1 = vertex_k1_k2.y;
	float k2 = vertex_k1_k2.z;
	
	curv_value = 0;
	if(u_curv_val == 1)
		curv_value = (k1+k2)/2.0;
	else if(u_curv_val == 2)
		curv_value = (k1*k2);
	else if(u_curv_val == 3)
		curv_value = k1;
	else if(u_curv_val == 4)
		curv_value = k2;
	
    gl_Position = vec4(position.xyz, 1);
}
#endif

#ifdef GEOMETRY_SHADER

#define TRANSFORMS_BINDING 0

layout (triangles) in;
layout (triangle_strip, max_vertices = 25) out;

layout (std140, binding = TRANSFORMS_BINDING)
uniform Transforms {
	mat4 modelview;
	mat4 projection;
	mat4 modelviewprojection;
	mat4 invmodelview;
} u_transforms;


uniform vec3 u_scene_size;
uniform vec2 u_viewport;
uniform int u_curv_dir;
/*uniform float u_lvl;
uniform float u_curv_radius;
uniform float u_size_tex;
uniform sampler3D densities;
uniform sampler3D u_xyz2_tex;
uniform sampler3D u_xy_yz_xz_tex;
uniform sampler3D u_xyz_tex;
uniform int u_curv_val;
*/

in vec3 vertex_k1_k2[];
in vec3 vertex_position[];
in vec3 vertex_color[];
in vec3 curv_dir_max[];
in vec3 curv_dir_min[];
in vec3 curv_normale[];
in float curv_value[];

out vec3 geometry_k1_k2;
out vec3 geometry_min_dir;
out vec3 geometry_max_dir;
out vec3 geometry_position;
out vec3 geometry_normale;
out vec3 geometry_egv;
out vec3 geometry_covmatDiag;
out vec3 geometry_covmatUpper;

out vec3 geometry_distance;
out vec3 geometry_color;
out float geometry_curv_value;
out flat int geometry_curvdir;

void setPoint(vec3 point, vec3 color)
{
	geometry_curvdir = 1;
	gl_Position = u_transforms.modelviewprojection * vec4(point, 1 );
	geometry_position = point.xyz;
	geometry_color = color;
}

/*
void drawTetra( vec3 pts[3], vec3 mean_dir, vec3 color )
{
	vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, normalize(pts[0]-pts[2]).xyz));
	float decalage = 3;
	float width = 0.1;
	
	vec3 p0 = pts[0].xyz + decalage*normale;
	vec3 p1 = p0 + mean_dir*5;
	vec3 p2 =pts[0].xyz  + (width*(pts[0].xyz - pts[1].xyz)) + decalage*normale;
	vec3 p3 = pts[0].xyz + width*(pts[0].xyz  - pts[2].xyz) + decalage*normale;
	
	setPoint(p0, color);
	EmitVertex();
	setPoint(p2, color);
	EmitVertex();
	setPoint(p1, color);
	EmitVertex();
	setPoint(p3, color);
	EmitVertex();
	
	EndPrimitive();
	
	p1 = p0 - mean_dir*5;
	
	setPoint(p0, color);
	EmitVertex();
	setPoint(p2, color);
	EmitVertex();
	setPoint(p1, color);
	EmitVertex();
	setPoint(p3, color);
	EmitVertex();
	
	EndPrimitive();
}
*/

vec3 reorientNormal(vec3 pts[3], vec3 given_normale)
{
	vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, normalize(pts[0]-pts[2]).xyz));
	if (dot(normalize(given_normale), normalize(normale)) < 0)
		given_normale *= -1;
	return given_normale;
}

void drawParallelpitruc( vec3 pts[3], vec3 mean_dir, vec3 color )
{		
		vec3 center_face = vec3(int(pts[0].x), pts[0].y, int(pts[0].z));// (pts[0].xyz+pts[1].xyz+pts[2].xyz)/3.0;
		vec3 normale = normalize(cross(normalize(pts[0]-pts[1]).xyz, normalize(pts[0]-pts[2]).xyz));
		vec3 tan_dir = normalize(pts[0]-pts[1]);
		vec3 depth = normalize(cross(normalize(tan_dir), normalize(mean_dir)));
		
		float l = 0.1*max( max(length(pts[0]-pts[2]), length(pts[0]-pts[1])), length(pts[1]-pts[2]) );
		float L = 10*l;
		float p = l;
		
		vec3 middle_geom = center_face + 0.5*L*normale;
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
		
		vec3 shade = color;
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
		
		geometry_color = vertex_color[i];
		geometry_curv_value = curv_value[i];
		geometry_curvdir = 0;
		
		geometry_k1_k2 = vertex_k1_k2[i];
		geometry_min_dir = curv_dir_min[i].xyz;
		geometry_max_dir = curv_dir_max[i].xyz;
		geometry_position = vertex_position[i].xyz;
		
		geometry_normale = curv_normale[i];// reorientNormal(pts, curv_normale[i]);
		/*geometry_covmatDiag = covmatDiag[i];
		geometry_covmatUpper = covmatUpper[i];
		geometry_egv = eigenvalues[i];*/
		
		gl_Position = transformed[i];
		EmitVertex();
	}
	
	EndPrimitive();
	
	if (u_curv_dir == 1 || u_curv_dir == 3)
	{
		//if ( ( int( pts[0].x ) % 10 == 0 ) && ( int( pts[0].z ) % 10 == 0 ) )
		drawParallelpitruc(pts, curv_dir_min[0], vec3(0, 0, 1));
	}
	
	if (u_curv_dir == 2 || u_curv_dir == 3)
	{
		drawParallelpitruc(pts, curv_dir_max[0], vec3(1, 0, 0));
	}
	
	if (u_curv_dir == 4)
	{
		drawParallelpitruc(pts, curv_normale[0], curv_normale[0]);
	}
}

#endif


#ifdef FRAGMENT_SHADER

#define TRANSFORMS_BINDING 0

layout(early_fragment_tests) in;

in vec3 geometry_k1_k2;
in vec3 geometry_min_dir;
in vec3 geometry_max_dir;
in vec3 geometry_position;
in vec3 geometry_normale;

in vec3 geometry_distance;
in vec3 geometry_color;
in float geometry_curv_value;
in flat int geometry_curvdir;


uniform float u_kmin;
uniform float u_kmax;
uniform int solid_wireframe;
uniform int u_triangle_normals;
uniform int u_curv_val;
/*uniform int u_curv_dir;
uniform vec3 u_scene_size;
uniform float u_lvl;
uniform float u_curv_radius;
uniform float u_size_tex;
uniform sampler3D densities;
uniform sampler3D u_xyz2_tex;
uniform sampler3D u_xy_yz_xz_tex;
uniform sampler3D u_xyz_tex;
*/

out vec4 fragment_color;

layout (std140, binding = TRANSFORMS_BINDING)
uniform Transforms {
	mat4 modelview;
	mat4 projection;
	mat4 modelviewprojection;
	mat4 invmodelview;
} u_transforms;

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

vec3 gradientmap( float scale )
{
  const int intervals = 2; //3 colors
  int upper_index = int( ceil( intervals * scale ) );
  if ( upper_index == 0 ) // Special case when value == min.
    upper_index = 1;
    
  vec3 colors[3];
  colors[0] = vec3(0, 0, 1);
  colors[1] = vec3(1, 0, 0);
  colors[2] = vec3(1, 1, 0);
  
  
  vec3 firstColor = colors[upper_index-1];
  vec3 lastColor = colors[upper_index];
	
  scale = ( scale * intervals ) - (upper_index - 1);

  return firstColor + scale * (lastColor - firstColor);
}

vec3 colorFromCurv(float c)
{
	vec3 color;
	float gt_curvature = c;
	if(u_kmax > u_kmin)
		gt_curvature = (c-u_kmin) / (u_kmax-u_kmin);

	if ((gt_curvature<0) || (gt_curvature>1)) color= vec3(0.5,0.5,0.5);
	else
		color= gradientmap(gt_curvature);
	
	return color;
}

void main( )
{
	vec3 color;
	if (geometry_curvdir == 0)
	{
		if (u_curv_val != 0)
			color = colorFromCurv(geometry_curv_value);
		else
			color = abs(geometry_color);
	}
	else
		color = abs(geometry_color);
	
	vec3 normale;
	if( u_triangle_normals == 1 )
		normale = normalize(cross( dFdx(geometry_position.xyz), dFdy(geometry_position.xyz)));
	else
		normale = geometry_normale;
	
	//Phong
	
	vec3 light_dir = vec3(1, 1, 1);
	normale = (u_transforms.modelview * vec4(normale, 0)).xyz;
	
	float shadow_weight = 0.5;
	float dotnormal = clamp(dot(normalize(normale), normalize(light_dir.xyz)), 0, 1);
	vec3 diffuse = shadow_weight * color * dotnormal + (1-shadow_weight) * color;
	
	vec3 R = reflect(-normalize(light_dir), normalize(normale));
	float ER = clamp(dot(normalize(vec3(0, 0, 1)), normalize(R)), 0, 1);
	vec3 specular = vec3(1) * pow(ER, 100);
	
	fragment_color = vec4(diffuse+specular, 1);
	//fragment_color = vec4(abs(normalize(normale)), 1);

	if (geometry_curvdir == 0 && solid_wireframe == 1)
	{
		const float wirescale = 0.5; // scale of the wire
		vec3 d2 = geometry_distance * geometry_distance;
		float nearest = min (min (d2.x, d2.y), d2.z);
		float f = exp2 (-nearest / wirescale);
		fragment_color = mix (fragment_color, vec4(0), f);
	}
}
#endif
