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

#include "Parameters.h"

#include <stdlib.h>

Parameters* Parameters::instance = NULL;

Parameters::Parameters()
{
    g_window.width = 1200;
    g_window.height = 600;
    g_window.major = 3;
    g_window.minor = 2;
    g_window.msaa_factor = 1; // multisampling level
    g_window.msaa_fixedsamplelocations = true; // fixed sample locations for msaa

    g_framebuffer_region.p = gk::TVec2<float>(0, 0);
    g_framebuffer_region.mag = 1;

    g_capture.enabled = false;
    g_capture.count = 0;
    g_capture.frame = 0;

    g_geometry.affine.identity();
    g_geometry.pingpong = 1;
    g_geometry.freeze = false;
    g_geometry.scale[0] = 512;
    g_geometry.scale[1] = 512;
    g_geometry.scale[2] = 512;

    g_camera.fovy = 45.f;
    g_camera.znear = 0.01f;
    g_camera.zfar = 10000.f;
    g_camera.exposure = 3.f;

    g_mouse = MOUSE_GEOMETRY;
    
    g_draw_cells = false;
    g_draw_triangles = true;
    g_culling = true;
    //g_fromtexture = true;
    g_solid_wireframe = true;
    g_controls = false;
    g_gui = true;
    //g_radial_length = true;
    //g_textured_data = false;
	g_auto_refine = true;
	g_triangle_normals = false;
	g_curv_dir = 0;
	g_curv_val = 1;
	g_lvl = 2;

    g_ground_truth = 1;
    
    g_adaptive_geom = true;
    g_radius_show = true;

	g_curvradius = 8.0;
    g_curvmin = -0.5;
    g_curvmax = 0.5;
	
    g_scale = 10.0;
    g_tessel = 1.0;
    //g_isosurface = 0;
	
	g_export = false;
	g_compute_min_max = true;

    g_sizetex = 0;
    
    g_time_elapsed = 0;
}

Parameters* Parameters::getInstance()
{
    if (instance == NULL)
        instance = new Parameters();
    return instance;
}
