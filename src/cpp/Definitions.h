#ifndef DEFINITIONS_H_
#define DEFINITIONS_H_

#include "Vec.h"
#include "Transform.h"

// window params
struct window_t {
    int width,
        height,
        major,
        minor;
    int msaa_factor, // multisampling level
        msaa_fixedsamplelocations; // fixed sample locations for msaa
};

// framebuffer region params
struct framebuffer_region_t {
    gk::TVec2<float> p; // region center
    float mag; // magnification factor
};

// screen recording params
struct capture_t {
    bool enabled;
    int frame, // frame id
        count; // capture id
};

// geometry params
struct geometry_t {
    gk::Transform affine;
    //const char *dmap;
    int pingpong; // ping pong variable for quadtree
    bool freeze;   // freeze updates
    float scale[3];  // sceen scale
        //dscale; // displacement scale
};

struct shading_t {
    int mode,
        wire;
    unsigned char 
		tr_colour[4],
		colour[4],
		wire_colour[4];
};

// camera params
struct camera_t {
    float fovy,
            znear,
            zfar,
            exposure;
    gk::Vector pos;
};

// transforms
struct transforms_t {
    gk::Matrix4x4
            modelview,
            projection,
            modelviewprojection,
            invmodelview;
};

// mouse params
enum {MOUSE_NONE, MOUSE_FRAMEBUFFER, MOUSE_GEOMETRY, MOUSE_LIGHT};

// openGL objects
enum {PROGRAM_LTREE_LOD, PROGRAM_LTREE_CULL, PROGRAM_CELL_DRAW, PROGRAM_REGULAR_DRAW, PROGRAM_TRANSITION_DRAW, 
            PROGRAM_FRAMEBUFFER_BLIT, 
			PROGRAM_GTCURV, PROGRAM_APPROXCURV, PROGRAM_HIERARCHCURV,
			PROGRAM_SHADING,
			PROGRAM_SPHEREDRAW, PROGRAM_COUNT};
enum {FRAMEBUFFER_DEFAULT, FRAMEBUFFER_COUNT};
enum {VERTEX_ARRAY_EMPTY, VERTEX_ARRAY_LTREE_UPDATE1, VERTEX_ARRAY_LTREE_UPDATE2, 
		VERTEX_ARRAY_LTREE_RENDER1, VERTEX_ARRAY_LTREE_RENDER2, 
		VERTEX_ARRAY_LTREE_RENDER1_TR, VERTEX_ARRAY_LTREE_RENDER2_TR,
		VERTEX_ARRAY_OCTREE_RENDER1, VERTEX_ARRAY_OCTREE_RENDER2,
        VERTEX_ARRAY_CURVATURE, VERTEX_ARRAY_CURVATURE_TR,
		VERTEX_ARRAY_SHADING,
        VERTEX_ARRAY_SPHERE_DRAW,
        VERTEX_ARRAY_COUNT};
enum {FEEDBACK_LTREE1, FEEDBACK_LTREE2, FEEDBACK_TRIANGULATION, FEEDBACK_TRIANGULATION_TR, FEEDBACK_COUNT};
enum {BUFFER_TRANSFORMS, BUFFER_FRUSTUM, 
		BUFFER_LTREE_DATA1, BUFFER_LTREE_DATA2, BUFFER_CODE,
		BUFFER_LTREE_DATA1_TR, BUFFER_LTREE_DATA2_TR, BUFFER_NEIGHBOURS,
		BUFFER_VERTEX_CUBE, BUFFER_INDEX_CUBE, BUFFER_TRIANGULATION, BUFFER_DIR_CURVATURE,
		BUFFER_INDIRECT_DRAWS, BUFFER_INDICES, BUFFER_VERTICES,
		BUFFER_INDIRECT_DRAWS_TR, BUFFER_INDICES_TR, BUFFER_VERTICES_TR,
		BUFFER_VERTEX_SPHERE, BUFFER_INDEX_SPHERE, 
		BUFFER_COUNT};

// shading params
enum {SHADING_COLOUR, SHADING_NORMAL, SHADING_TEXCOORDS, SHADING_LAMBERT};

// textures
enum {
		TEXTURE_RGBA, TEXTURE_Z, 
		TEXTURE_COLOR_X,
		TEXTURE_COLOR_Y,
		TEXTURE_COLOR_Z,
		TEXTURE_BUMP_X,
		TEXTURE_BUMP_Y,
		TEXTURE_BUMP_Z,
		TEXTURE_ENVMAP,
		TEXTURE_DENSITY, 
		TEXTURE_X2Y2Z2,
		TEXTURE_XY_YZ_XZ,
		TEXTURE_XYZ,
		TEXTURE_CODE_CLASS, 
		TEXTURE_CODE_VERTICES, 
		TEXTURE_CLASS_TRIANGLES, 
		TEXTURE_CODE_CLASS_TR, 
		TEXTURE_CODE_VERTICES_TR ,
		TEXTURE_CLASS_TRIANGLES_TR,
		TEXTURE_COUNT};

// uniform locations
enum {
	LOCATION_LOD_SCENE_SIZE,
	LOCATION_LOD_TAN_FOVY,
	LOCATION_LOD_SCALE,
	LOCATION_LOD_DENSITY,
	LOCATION_LOD_FROMTEXTURE,
	LOCATION_LOD_METRIC,
	LOCATION_LOD_TIME,
	LOCATION_LOD_REGULAR,
	LOCATION_LOD_SIZETEX,

	LOCATION_CULL_SCENE_SIZE,
	LOCATION_CULL_TAN_FOVY,
	LOCATION_CULL_DISABLED,
	LOCATION_CULL_DENSITY,
	LOCATION_CULL_SCALE,
	LOCATION_CULL_TESSEL,
	LOCATION_CULL_ISOSURFACE,
	LOCATION_CULL_FROMTEXTURE,
	LOCATION_CULL_METRIC,
	LOCATION_CULL_TIME,
	LOCATION_CULL_SIZETEX,

	LOCATION_DRAW_SCENE_SIZE,
	LOCATION_DRAW_DENSITY,
	LOCATION_CELL_SCALE,
	LOCATION_CELL_TAN_FOVY,
	LOCATION_CELL_FROMTEXTURE,
	LOCATION_CELL_TIME,

	LOCATION_REGULAR_SCENE_SIZE,
	LOCATION_REGULAR_VIEWPORT,
	LOCATION_REGULAR_TAN_FOVY,
	LOCATION_REGULAR_DENSITY,
	LOCATION_REGULAR_CODE_CLASS,
	LOCATION_REGULAR_CODE_VERTICES,
	LOCATION_REGULAR_CLASS_TRIANGLES,
	LOCATION_REGULAR_TESSEL,
	LOCATION_REGULAR_SCALE,
	LOCATION_REGULAR_ISOSURFACE,
	LOCATION_REGULAR_FROMTEXTURE,
	LOCATION_REGULAR_METRIC,
	LOCATION_REGULAR_TIME,

	LOCATION_TRANSITION_SCENE_SIZE,
	LOCATION_TRANSITION_VIEWPORT,
	LOCATION_TRANSITION_TAN_FOVY,
	LOCATION_TRANSITION_DENSITY,
	LOCATION_TRANSITION_CODE_CLASS_TR,
	LOCATION_TRANSITION_CODE_VERTICES_TR,
	LOCATION_TRANSITION_CLASS_TRIANGLES_TR,
	LOCATION_TRANSITION_TESSEL,
	LOCATION_TRANSITION_SCALE,
	LOCATION_TRANSITION_ISOSURFACE,
	LOCATION_TRANSITION_FROMTEXTURE,
	LOCATION_TRANSITION_METRIC,
	LOCATION_TRANSITION_TIME,

	LOCATION_FRAMEBUFFER_BLIT_VIEWPORT,
	LOCATION_FRAMEBUFFER_BLIT_SAMPLER,

	LOCATION_SHADING_SIZE,
	LOCATION_SHADING_DENSITY,
	LOCATION_SHADING_VIEWPORT,
	LOCATION_SHADING_TAN_FOVY,
	LOCATION_SHADING_SCALE,
	LOCATION_SHADING_WIREFRAME,
	LOCATION_SHADING_CAMERA,
	LOCATION_SHADING_CURVRADIUS,
	LOCATION_SHADING_CURVMIN,
	LOCATION_SHADING_CURVMAX,
	LOCATION_SHADING_GROUNDTRUTH,
	LOCATION_SHADING_SIZETEX,
	LOCATION_SHADING_XYZTEX,
	LOCATION_SHADING_XY_YZ_XZ_TEX,
	LOCATION_SHADING_XYZ_TEX,
	LOCATION_SHADING_DIR,
	
	LOCATION_GTCURV_SIZE,
	LOCATION_GTCURV_DENSITY,
	LOCATION_GTCURV_VIEWPORT,
	LOCATION_GTCURV_TAN_FOVY,
	LOCATION_GTCURV_SCALE,
	LOCATION_GTCURV_WIREFRAME,
	LOCATION_GTCURV_CAMERA,
	LOCATION_GTCURV_CURVRADIUS,
	LOCATION_GTCURV_CURVMIN,
	LOCATION_GTCURV_CURVMAX,
	LOCATION_GTCURV_GROUNDTRUTH,
	LOCATION_GTCURV_SIZETEX,
	LOCATION_GTCURV_XYZTEX,
	LOCATION_GTCURV_XY_YZ_XZ_TEX,
	LOCATION_GTCURV_XYZ_TEX,
	LOCATION_GTCURV_DIR,
	LOCATION_GTCURV_CURVVAL,
	
	LOCATION_HIERARCHCURV_SIZE,
	LOCATION_HIERARCHCURV_DENSITY,
	LOCATION_HIERARCHCURV_VIEWPORT,
	LOCATION_HIERARCHCURV_TAN_FOVY,
	LOCATION_HIERARCHCURV_SCALE,
	LOCATION_HIERARCHCURV_WIREFRAME,
	LOCATION_HIERARCHCURV_CAMERA,
	LOCATION_HIERARCHCURV_CURVRADIUS,
	LOCATION_HIERARCHCURV_CURVMIN,
	LOCATION_HIERARCHCURV_CURVMAX,
	LOCATION_HIERARCHCURV_GROUNDTRUTH,
	LOCATION_HIERARCHCURV_SIZETEX,
	LOCATION_HIERARCHCURV_XYZTEX,
	LOCATION_HIERARCHCURV_XY_YZ_XZ_TEX,
	LOCATION_HIERARCHCURV_XYZ_TEX,
	LOCATION_HIERARCHCURV_DIR,
	LOCATION_HIERARCHCURV_CURVVAL,
	
	LOCATION_APPROXCURV_SIZE,
	LOCATION_APPROXCURV_DENSITY,
	LOCATION_APPROXCURV_VIEWPORT,
	LOCATION_APPROXCURV_TAN_FOVY,
	LOCATION_APPROXCURV_SCALE,
	LOCATION_APPROXCURV_WIREFRAME,
	LOCATION_APPROXCURV_CAMERA,
	LOCATION_APPROXCURV_CURVRADIUS,
	LOCATION_APPROXCURV_CURVMIN,
	LOCATION_APPROXCURV_CURVMAX,
	LOCATION_APPROXCURV_GROUNDTRUTH,
	LOCATION_APPROXCURV_SIZETEX,
	LOCATION_APPROXCURV_XYZTEX,
	LOCATION_APPROXCURV_XY_YZ_XZ_TEX,
	LOCATION_APPROXCURV_XYZ_TEX,
	LOCATION_APPROXCURV_DIR,
	LOCATION_APPROXCURV_CURVVAL,

	LOCATION_SPHEREDRAW_SCENE_SIZE,
	LOCATION_SPHEREDRAW_CURVRADIUS,
	LOCATION_SPHEREDRAW_SIZETEX,
	
	LOCATION_COUNT
};

enum {   
	QUERY_LOD,
	QUERY_REGULAR,
	QUERY_TRANSITION,
        QUERY_TRIANGLES,
	QUERY_COUNT 
};

#endif

