// author: Jonathan Dupuy (jdupuy@liris.cnrs.fr)
// author: Helene Perrier 

#include "Parameters.h"
#include "GpuOctree.h"
#include "BlitFramebuffer.h"
#include "DataLoader.h"
#include "Triangulation.h"
#include "Shading.h"
#include "QuaternionCamera.h"

#include "GL/GLQuery.h"
#include "GL/GLTexture.h"
#include "App.h"
#include "ProgramManager.h"
#include "Format.h"

#include <cmath>

#define CAM_SPEED 40
#define CAM_SPEED_MAX Parameters::getInstance()->g_geometry.scale[0] / 5.0
#define CAM_ROTATE 0.1f
#define CAM_ROTATE_MAX 1.0f

void updateMatricesAndFrustum()
{
	//build matrices
	{
		Parameters::getInstance()->g_transforms.projection =
			gk::Perspective( Parameters::getInstance()->g_camera.fovy,
			(float)Parameters::getInstance()->g_window.width / (float)Parameters::getInstance()->g_window.height,
			Parameters::getInstance()->g_camera.znear,
			Parameters::getInstance()->g_camera.zfar).matrix();

		Parameters::getInstance()->g_transforms.modelviewprojection =
			gk::Matrix4x4::mul(Parameters::getInstance()->g_transforms.projection,
			Parameters::getInstance()->g_geometry.affine.matrix()
			).transpose();
		
		if (!Parameters::getInstance()->g_geometry.freeze) 
		{
			Parameters::getInstance()->g_transforms.modelview = Parameters::getInstance()->g_geometry.affine.matrix().transpose();
			Parameters::getInstance()->g_transforms.invmodelview = Parameters::getInstance()->g_transforms.modelview.getInverse();
		}
	}

	// update frustum
	if (!Parameters::getInstance()->g_geometry.freeze) 
	{
		buildFrustum(Parameters::getInstance()->g_frustum, Parameters::getInstance()->g_transforms.modelviewprojection);
		streamFrustum ();
	}

	// upload matrices
	#define STREAM_BUFFER_BYTE_SIZE (1 << 10)
	const int mapflags = GL_MAP_WRITE_BIT | GL_MAP_UNSYNCHRONIZED_BIT;
	const int stream_byte_size = sizeof (Parameters::getInstance()->g_transforms);
	static int buffer_byte_offset = STREAM_BUFFER_BYTE_SIZE;
	static bool first = true;
	int buffer;
	float *map;

	// upload to GPU
	glGetIntegerv (GL_UNIFORM_BUFFER_BINDING, &buffer);
	glBindBuffer (GL_UNIFORM_BUFFER, Parameters::getInstance()->g_buffers[BUFFER_TRANSFORMS]);
	if (first) { // first initialisation
		glGenBuffers (1, &Parameters::getInstance()->g_buffers[BUFFER_TRANSFORMS]);
		glBindBuffer (GL_UNIFORM_BUFFER, Parameters::getInstance()->g_buffers[BUFFER_TRANSFORMS]);
		glBufferData (GL_UNIFORM_BUFFER, STREAM_BUFFER_BYTE_SIZE, NULL, GL_DYNAMIC_DRAW);
		first = false;
	}
	if (buffer_byte_offset + stream_byte_size > STREAM_BUFFER_BYTE_SIZE) {
		buffer_byte_offset = 0; // orphan
	}
	map = (float*)glMapBufferRange (GL_UNIFORM_BUFFER, buffer_byte_offset,
				stream_byte_size, mapflags);
	memcpy (map, &Parameters::getInstance()->g_transforms, stream_byte_size);
	glUnmapBuffer (GL_UNIFORM_BUFFER);
	glBindBuffer (GL_UNIFORM_BUFFER, buffer);
	glBindBufferRange (GL_UNIFORM_BUFFER,
			  BUFFER_TRANSFORMS,
			  Parameters::getInstance()->g_buffers[BUFFER_TRANSFORMS],
			  buffer_byte_offset, stream_byte_size);
	buffer_byte_offset+= stream_byte_size;
}

void activateTextures()
{
	glActiveTexture(GL_TEXTURE0 + TEXTURE_DENSITY);
	glBindTexture(GL_TEXTURE_3D, Parameters::getInstance()->g_textures[TEXTURE_DENSITY]);
	
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CODE_CLASS);
	glBindTexture(GL_TEXTURE_1D, Parameters::getInstance()->g_textures[TEXTURE_CODE_CLASS]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CODE_VERTICES);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_CODE_VERTICES]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CLASS_TRIANGLES);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_CLASS_TRIANGLES]);
	
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CODE_CLASS_TR);
	glBindTexture(GL_TEXTURE_1D, Parameters::getInstance()->g_textures[TEXTURE_CODE_CLASS_TR]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CODE_VERTICES_TR);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_CODE_VERTICES_TR]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_CLASS_TRIANGLES_TR);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_CLASS_TRIANGLES_TR]);
	
	glActiveTexture(GL_TEXTURE0 + TEXTURE_COLOR_X);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_COLOR_X]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_COLOR_Y);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_COLOR_Y]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_COLOR_Z);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_COLOR_Z]);
	
	glActiveTexture(GL_TEXTURE0 + TEXTURE_BUMP_X);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_BUMP_X]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_BUMP_Y);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_BUMP_Y]);
	glActiveTexture(GL_TEXTURE0 + TEXTURE_BUMP_Z);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_BUMP_Z]);
	
	glActiveTexture(GL_TEXTURE0 + TEXTURE_ENVMAP);
	glBindTexture(GL_TEXTURE_2D, Parameters::getInstance()->g_textures[TEXTURE_ENVMAP]);
}

void setShaderCameraPos(const gk::Transform& tr)
{
	Parameters::getInstance()->g_camera.pos[0] = tr.matrix()[3];
	Parameters::getInstance()->g_camera.pos[1] = tr.matrix()[1*4 + 3];
	Parameters::getInstance()->g_camera.pos[2] = tr.matrix()[2*4 + 3];
}

class Vizo : public gk::App
{

private:
    
    //Gui
	nv::SdlContext m_widgets;

	//Execution time measuring queries
	gk::GLQuery *m_time_lod;
	gk::GLQuery *m_time_cull;
	gk::GLQuery *m_time_render_regular;
	gk::GLQuery *m_time_render_transition;
	gk::GLQuery *m_time_shading;
	gk::GLQuery *m_time_blit;

	//Camera parameters
	float cam_speed;
	float cam_rotate;
	QuaternionCamera cam;
	
	//algorithm
	GPUOctree lodManager;
	Triangulation extractor;
	
	//Framebuffer
	Shading shadator;
	BlitFramebuffer blitter;
	
	//Data Loaded
	DataLoader* dl;
	char** argv;
	int argc;

	//Bench
	int frame;
	
	GLuint queryResult_lod;
	GLuint queryResult_regular;
	GLuint queryResult_transition;
	
	GLuint triangles_regular;
	GLuint triangles_transition;
	
	GLuint unmovedCells;
	
	GLuint64 gpu_lod_time;
	GLuint64 gpu_cull_time;
	GLuint64 gpu_render_time_regular;
	GLuint64 gpu_render_time_transition;
	GLuint64 gpu_shading_time;
	GLuint64 gpu_blit_fbo;
	float gpu_time;
	
	GLuint64 sync_cell_cull;
	GLuint64 sync_count_triangles;
	
	//Plot file
	FILE* plotfd;
	
	//CPU flags
	bool skybox;
	bool animate;
	bool plot;
	bool transition_cells_displayed;
	bool reload_fetch;
	
public:
	Vizo(int _argc, char** _argv) : gk::App()
	{
		//Creates OpenGL's context
		gk::AppSettings settings;
		settings.setGLVersion(3,3);    
		settings.setGLCoreProfile(); 
		settings.setGLDebugContext();  

		//Creates the window
		if(createWindow(Parameters::getInstance()->g_window.width, Parameters::getInstance()->g_window.height, settings) < 0)
			closeWindow();

		//Init gui
		m_widgets.init();
		m_widgets.reshape(windowWidth(), windowHeight());
		
		argc = _argc;
		argv = _argv;
	}
    
	~Vizo( ) {}
	    
	int init( )
	{
		//Create queries
		fprintf(stdout, "Status: Using GLEW %s\n", glewGetString(GLEW_VERSION));
		m_time_lod = gk::createTimeQuery();
		m_time_cull = gk::createTimeQuery();
		m_time_render_regular = gk::createTimeQuery();
		m_time_render_transition = gk::createTimeQuery();
		m_time_shading = gk::createTimeQuery();
		m_time_blit = gk::createTimeQuery();
		
		//init camera parameters
		cam_speed = CAM_SPEED;
		cam_rotate = CAM_ROTATE;

		int type = atoi(argv[2]);
		if (type == 1)
		{
			float size = 256;
			if (argc >= 4)
				size = atoi(argv[3]);
			dl = new DataRaw(size);
		}
		dl->loadFile(argv[1]);
		dl->loadData32BGpu();
		
		lodManager.init();
		extractor.init();
		shadator.init();
		blitter.init();
		
		queryResult_lod = 0;
		queryResult_regular = 0;
		queryResult_transition = 0;
		triangles_regular = 0;
		triangles_transition = 0;
		unmovedCells = 0;
		frame = 0;
		
		skybox = false;
		animate = true;
		plot = false;
		transition_cells_displayed = true;
		
		// OpenGL context flags
		glEnable (GL_DEPTH_TEST);
		glDisable (GL_CULL_FACE);
		glPatchParameteri (GL_PATCH_VERTICES, 4);
		
		glClearColor(1, 1, 1, 1);
		
		activateTextures();
		
		plotfd = fopen("plot.txt","w");
		if (plotfd == NULL)
			perror("fopen");
		
		fprintf(plotfd, "# Frame \t\t TotalCells \t\t RegCells \t\t TrCells \t\t Tgl \t\t LodTime (ms) \t\t CullTime (ms) \t\t RegTglTime (ms) \t\t TrTglTime (ms)\t\t ShadingTime (ms)\t\t ShdLessTime (ms)\t\t TotalTime (ms) \t\t Cpu Time (ns)\n");
		
		if (Parameters::getInstance()->g_controls == true)
			load_quatPoint(cam);
		else 
			load_viewPoint();
		
		reload_fetch = Parameters::getInstance()->g_fromtexture;
		
		return 0;
	}
    
	void window_draw ()
	{
		//return;
		
		updateMatricesAndFrustum();
		
		if(!Parameters::getInstance()->g_geometry.freeze) 
		{
			/** Update the octree **/
			lodManager.configurePrograms();
			
			glEnable(GL_RASTERIZER_DISCARD);
        
			m_time_lod->begin();

			lodManager.runLod(&unmovedCells, &queryResult_lod);
		
			m_time_lod->end();

                        /** Cull useless cells **/
                        
			m_time_cull->begin();
		
			lodManager.runCull(&queryResult_regular, &queryResult_transition, &sync_cell_cull);
		
			m_time_cull->end();
				
			Parameters::getInstance()->g_geometry.pingpong = 1 - Parameters::getInstance()->g_geometry.pingpong;
		}
		
		if(queryResult_regular > 0) 
		{
			//generate triangles
			m_time_render_regular->begin();
			
			extractor.runRegular(queryResult_regular);
			
			m_time_render_regular->end();
		}
		
		if (transition_cells_displayed && queryResult_transition > 0)
		{
			m_time_render_transition->begin();
			
			extractor.runTransition(queryResult_transition);
			
			m_time_render_transition->end();
		}
		
		
		glBindFramebuffer (GL_FRAMEBUFFER, Parameters::getInstance()->g_framebuffers[FRAMEBUFFER_DEFAULT]);   
		glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glEnable(GL_DEPTH_TEST);

		glViewport    (0, 0, Parameters::getInstance()->g_window.width, Parameters::getInstance()->g_window.height);
		glPolygonMode (GL_FRONT_AND_BACK, GL_FILL);
		
		if(skybox)
		{
		    glDisable(GL_DEPTH_TEST);
		    glPolygonMode (GL_FRONT_AND_BACK, GL_FILL);
		    
		    glUseProgram (Parameters::getInstance()->g_programs[PROGRAM_SKYBOX]);
		    glBindVertexArray (Parameters::getInstance()->g_vertex_arrays[VERTEX_ARRAY_EMPTY]);
		    glDrawArrays (GL_TRIANGLE_STRIP, 0, 4);
		    glBindVertexArray(0);
		    glUseProgram(0);
		    
		    glEnable(GL_DEPTH_TEST);
		}

		//draw octree
		if (Parameters::getInstance()->g_draw_cells)
		{
			lodManager.runDisplay(queryResult_regular);
		}
		
		if (Parameters::getInstance()->g_draw_triangles)
		{
			m_time_shading->begin();
			
			shadator.run(queryResult_regular, queryResult_transition, &triangles_regular, &triangles_transition, &sync_count_triangles);
			
			m_time_shading->end();
		}
		
		//fprintf(stdout, "%lf %lf %lf -- ", Parameters::getInstance()->g_camera.pos[0], Parameters::getInstance()->g_camera.pos[1], Parameters::getInstance()->g_camera.pos[2]);
		//fprintf(stdout, "[Cells] Total %d Regular %d Transition %d // [Triangles] Regular %d Transition %d ...\r", 
		//	queryResult_lod, queryResult_regular, queryResult_transition, triangles_regular, triangles_transition); fflush(stdout);
       
		m_time_blit->begin();
		
		blitter.blit();
                
		m_time_blit->end();
	}
    
	int quit( )
	{
		int i;
		for (i = 0; i < PROGRAM_COUNT; ++i) glDeleteProgram (Parameters::getInstance()->g_programs[i]);
		glDeleteVertexArrays (VERTEX_ARRAY_COUNT, Parameters::getInstance()->g_vertex_arrays);
		glDeleteFramebuffers (FRAMEBUFFER_COUNT, Parameters::getInstance()->g_framebuffers);
		glDeleteTextures (TEXTURE_COUNT, Parameters::getInstance()->g_textures);
		glDeleteBuffers (BUFFER_COUNT, Parameters::getInstance()->g_buffers);
		glDeleteVertexArrays (VERTEX_ARRAY_COUNT, Parameters::getInstance()->g_vertex_arrays);
		glDeleteTransformFeedbacks(FEEDBACK_COUNT, Parameters::getInstance()->g_feedbacks);
		glDeleteQueries(1, &Parameters::getInstance()->g_query[QUERY_REGULAR]);
		glDeleteQueries(1, &Parameters::getInstance()->g_query[QUERY_TRANSITION]);
		fclose(plotfd);
		return 0;
	}

	// Needs to be redefined for widget use
	void processWindowResize( SDL_WindowEvent& event )
	{
		m_widgets.reshape(event.data1, event.data2);
	}

	// Needs to be redefined for widget use
	void processMouseButtonEvent( SDL_MouseButtonEvent& event )
	{
		m_widgets.processMouseButtonEvent(event);
	}

	// Needs to be redefined for widget use
	void processMouseMotionEvent( SDL_MouseMotionEvent& event )
	{
		m_widgets.processMouseMotionEvent(event);
	}

	// Needs to be redefined for widget use
	void processKeyboardEvent( SDL_KeyboardEvent& event )
	{
		m_widgets.processKeyboardEvent(event);
	}

	void testParameters()
	{
		
		if(key(SDLK_ESCAPE))
			closeWindow();
                //reload and rebuild shaders
		if(key('r'))
		{
			lodManager.loadPrograms();
			extractor.loadPrograms();
			shadator.loadProgram();
			gk::reloadPrograms();
			key('r')= 0;
		}
		if(key('w'))
		{
			Parameters::getInstance()->g_solid_wireframe = !Parameters::getInstance()->g_solid_wireframe;
			key('w')= 0;
		}
		
		if (key('f'))
		{
			Parameters::getInstance()->g_geometry.freeze = !Parameters::getInstance()->g_geometry.freeze;
			key('f') = 0;
		}
		
		if(key('g'))
		{
			Parameters::getInstance()->g_gui = !Parameters::getInstance()->g_gui;
			key('g') = 0;
		}
			
		if(key('o'))
		{
			Parameters::getInstance()->g_draw_cells = !Parameters::getInstance()->g_draw_cells;
			key('o') = 0;
		}
		
		if(key('p'))
		{
			plot = !plot;
			key('p') = 0;
		}
			
		if (key('c'))
		{
			Parameters::getInstance()->g_capture.enabled = !Parameters::getInstance()->g_capture.enabled;
			key('c') = 0;
		}
		
		if (key('a'))
		{
			animate = !animate;
			key('a') = 0;
		}
		
		if (reload_fetch != Parameters::getInstance()->g_fromtexture)
		{
			if (Parameters::getInstance()->g_fromtexture)
			{
				Parameters::getInstance()->g_controls = true;
				load_quatPoint(cam);
				
				animate = false;
				
				Parameters::getInstance()->g_scale = 3.7;
				Parameters::getInstance()->g_tessel = 2;
			}
			else
			{
				Parameters::getInstance()->g_controls = false;
				load_viewPoint();
				
				animate = true;
				
				Parameters::getInstance()->g_scale = 7;
				Parameters::getInstance()->g_tessel = 2;
			}
		}
		
		reload_fetch = Parameters::getInstance()->g_fromtexture;
	}
    
	void testMovement()
	{
		int x, y;
		int button = SDL_GetRelativeMouseState(&x, &y);
		
		if (Parameters::getInstance()->g_controls)
		{
			//MATRIX
			/*if(button & SDL_BUTTON(1))
			{
				if (fabs(x) > fabs(y))
					Parameters::getInstance()->g_geometry.affine = gk::Rotate(x*cam_rotate, gk::Vector(0, 1, 0)) * Parameters::getInstance()->g_geometry.affine;
				else
					Parameters::getInstance()->g_geometry.affine = gk::Rotate(y*cam_rotate, gk::Vector(1, 0, 0)) * Parameters::getInstance()->g_geometry.affine;
			}
			
			if(key('s'))
				Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, 0, -cam_speed*0.5)) *
						Parameters::getInstance()->g_geometry.affine;
			if(key('z'))
				Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, 0, cam_speed*0.5)) *
						Parameters::getInstance()->g_geometry.affine;*/
			
						
			//QUATERNION
			if(key('s'))
				cam.moveBackward(cam_speed);//*(gpu_time/1000.0));
			if(key('z'))
				cam.moveForward(cam_speed);//*(gpu_time/1000.0));
			
			if(button & SDL_BUTTON(1))
			{
				cam.rotate(x, y);
			}
			
			Parameters::getInstance()->g_geometry.affine = cam.getMatrix();
		}
		else
		{
			if(button & SDL_BUTTON(1))
			{
				if (Parameters::getInstance()->g_mouse == MOUSE_FRAMEBUFFER) 
				{
					Parameters::getInstance()->g_framebuffer_region.p[0]-= x / Parameters::getInstance()->g_framebuffer_region.mag;
					Parameters::getInstance()->g_framebuffer_region.p[1]+= y / Parameters::getInstance()->g_framebuffer_region.mag;
					updateFramebufferRegion ();
				} else if (Parameters::getInstance()->g_mouse == MOUSE_GEOMETRY) 
				{
					rotateLocal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(0, 1, 0), x*cam_rotate);
					rotateLocal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(1, 0, 0), y*cam_rotate);
				}
			}
			
			if(SDL_GetModState() & KMOD_CTRL)
			{
				if(key(SDLK_PAGEDOWN))
				{
					rotateLocal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(1, 0, 0), -4*cam_rotate);
				}
				if(key(SDLK_PAGEUP))
				{
					rotateLocal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(1, 0, 0), 4*cam_rotate);
				}
				if(key(SDLK_RIGHT))
				{
					rotateGlobal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(0, 1, 0), 4*cam_rotate);
				}
				if(key(SDLK_LEFT))
				{
					rotateGlobal_noTranslation(Parameters::getInstance()->g_geometry.affine, gk::Vector(0, 1, 0), -4*cam_rotate);
				}
				if(key(SDLK_UP))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, 0, cam_speed)) * //*(gpu_time/1000.0))) *
						Parameters::getInstance()->g_geometry.affine;
				}
				if(key(SDLK_DOWN))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, 0, -cam_speed)) * //*(gpu_time/1000.0))) *
						Parameters::getInstance()->g_geometry.affine;
				}
			}
			else
			{
				if(key(SDLK_UP))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, -cam_speed, 0)) * //*(gpu_time/1000.0), 0)) *
						Parameters::getInstance()->g_geometry.affine;
				}
				if(key(SDLK_DOWN))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(0, cam_speed, 0)) * //*(gpu_time/1000.0), 0)) *
						Parameters::getInstance()->g_geometry.affine;
				}
				if(key(SDLK_RIGHT))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(-cam_speed, 0, 0)) * //*(gpu_time/1000.0), 0, 0)) *
						Parameters::getInstance()->g_geometry.affine;
				}
				if(key(SDLK_LEFT))
				{
					Parameters::getInstance()->g_geometry.affine =
						gk::Translate(gk::Vector(cam_speed, 0, 0)) * //*(gpu_time/1000.0), 0, 0)) *
						Parameters::getInstance()->g_geometry.affine;
				}
			}
			
			/*
			gk::Vector rot = gk::Vector(0, -0.004, 0);
			rot = Normalize(rot);
			
			rotateGlobal_noTranslation(
				Parameters::getInstance()->g_geometry.affine, 
						   rot, 0.1);
			Parameters::getInstance()->g_geometry.affine =
						gk::Translate(
							gk::Vector(0.004, 0, 0)
						    ) *
						Parameters::getInstance()->g_geometry.affine;*/
			
		}
		
		/*
		static float speed = 0.2;
		static float rot_speed = 0.5;
		
		static bool turn = false;
		
		float initfr = 0;
		float nb_step = 3.5;
		float step = 300;
		if (frame >= initfr && frame <= initfr + nb_step*step)
		{
			if (frame >= initfr + step && frame <= initfr + 2*step)
				Parameters::getInstance()->g_solid_wireframe = true;
			else
				Parameters::getInstance()->g_solid_wireframe = false;
			
			if (frame > initfr + 2.5*step)
				animate = true;
		}
		else
		{
			if (!turn)
			{
				float state = sin(Parameters::getInstance()->g_time_elapsed * rot_speed);
				printf("sin(rot_speed) = %lf\n", state);
				cam.rotate( 2 * state, 0);
				if (frame >= 1650)
					turn = true;
			}
				
			cam.moveForward(speed);
			
			if (frame >= 2500)
				exit(0);
			
		}*/
		
		/*Parameters::getInstance()->g_geometry.affine =
				gk::Translate(gk::Vector(0, 0, -0.25)) *
				Parameters::getInstance()->g_geometry.affine;
				
		if (Parameters::getInstance()->g_camera.pos[2] = Parameters::getInstance()->g_geometry.affine.matrix()[2*4 + 3] < -800)
			exit(0);*/
		
		
		
		
		/*static float speed = 0.3;
		
		static float move = speed;
		static float rot = 2.5 * speed;
		static float move_tot = 0;
		static float rot_tot = 0;
		
		static float move_at_rot = -1;
		
		static float pause = 1;
		static float pause_count;
		
		static int pause_length = 800;
		static bool first = true;
		
		if (pause)
		{
			pause_count++;
			
			if (pause_count > pause_length)
				pause = 0;
			
			if ( (pause_count == (pause_length/2)) && (!first))
			{
				if (move_tot < 0)
					exit(0);
				
				if (Parameters::getInstance()->g_solid_wireframe)
				{
					Parameters::getInstance()->g_draw_cells = true;
					Parameters::getInstance()->g_solid_wireframe = false;
				}
				else
				{
					Parameters::getInstance()->g_draw_cells = false;
					Parameters::getInstance()->g_solid_wireframe = true;
				}
			}
		}
		else
		{
		
			first = false;
		
			cam.moveBackward(move);
			
			move_tot += move;
			if (move_tot > 180)
			{
				move = -speed;
				pause_count = 0;
				pause = 1;
			}

			
			cam.rotate(0, rot);
			rot_tot += rot;
			
			if (rot_tot > 250)
			{
				if (move_tot <= move_at_rot)
					rot = -2.5 * speed;
				
				if (move_at_rot == -1)
				{
					move_at_rot = move_tot;
					rot = 0;
				}
			}
			
			
			
			if (move_tot < 0)
			{
				pause = 1;
				pause_count = 0;
			}
			
			printf("rot %lf -- mov %lf\n", rot_tot, move_tot);
		}*/
		
		setShaderCameraPos(Parameters::getInstance()->g_geometry.affine);
	}
    
	void GUI(GLuint64 cpu_time)
	{
		m_time_lod->sync();
		gpu_lod_time= m_time_lod->result64() / 1000;
		m_time_cull->sync();
		gpu_cull_time= m_time_cull->result64() / 1000;
		m_time_render_regular->sync();
		gpu_render_time_regular = m_time_render_regular->result64() / 1000;
		m_time_render_transition->sync();
		gpu_render_time_transition = m_time_render_transition->result64() / 1000;
		m_time_shading->sync();
		gpu_shading_time = m_time_shading->result64() / 1000;
		m_time_blit->sync();
		gpu_blit_fbo = m_time_blit->result64() / 1000;
		
		gpu_time = (gpu_lod_time + gpu_cull_time + gpu_render_time_regular + gpu_render_time_transition + gpu_shading_time)/1000.0;
		int fps = 0;
		if (gpu_time == 0)
			gpu_time = 0.1;
		
		fps = 1000 / gpu_time;

		m_widgets.begin();
		m_widgets.beginGroup(nv::GroupFlags_GrowDownFromLeft);
		if (Parameters::getInstance()->g_gui)
		{
			
			char tmp[1024] = {0}; //used to display sliders names
			{
				m_widgets.doLabel(nv::Rect(), Format("FPS %d", fps));
				m_widgets.doLabel(nv::Rect(), Format("Frame %d", frame));
				
				m_widgets.doLabel(nv::Rect(), Format("effective cpu time % 6ldus", cpu_time));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus LOD", gpu_lod_time / 1000, gpu_lod_time % 1000));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus Cull", gpu_cull_time / 1000, gpu_cull_time % 1000));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus Triangulate Regular Cells", gpu_render_time_regular / 1000, gpu_render_time_regular % 1000));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus Triangulate Transition Cells", gpu_render_time_transition / 1000, gpu_render_time_transition % 1000));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus Shading", gpu_shading_time / 1000, gpu_shading_time % 1000));
				m_widgets.doLabel(nv::Rect(), Format("gpu time % 3ldms % 3ldus Blit to FB", gpu_blit_fbo / 1000, gpu_blit_fbo % 1000));

				//printf("Frame number %d\r", frame_number);

				/*sprintf(tmp, "Fovy %.2f", Parameters::getInstance()->g_camera.fovy);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 10.f, 180.f, &(Parameters::getInstance()->g_camera.fovy));*/
				sprintf(tmp, "Scale %.2f", Parameters::getInstance()->g_scale);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 2.f, 28.f, &(Parameters::getInstance()->g_scale));
				/*sprintf(tmp, "Tessellation %.2f", Parameters::getInstance()->g_tessel);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 1.f, 10.f, &(Parameters::getInstance()->g_tessel));
				sprintf(tmp, "Isosurface %.2f", Parameters::getInstance()->g_isosurface);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 0.f, 1.f, &(Parameters::getInstance()->g_isosurface));*/
				sprintf(tmp, "Curvature Radius %.2f", Parameters::getInstance()->g_curvradius);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 1.f, 30.f, &(Parameters::getInstance()->g_curvradius));
				sprintf(tmp, "Curvature Min %.2f", Parameters::getInstance()->g_curvmin);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), -5.f, 5.f, &(Parameters::getInstance()->g_curvmin));
				sprintf(tmp, "Curvature Max %.2f", Parameters::getInstance()->g_curvmax);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), -5.f, 5.f, &(Parameters::getInstance()->g_curvmax));
				
				static bool unfold_flags= 0;
				static bool unfold_actions= 0;
				static nv::Rect r_flags;
				static nv::Rect r_actions;
				if(m_widgets.beginPanel(r_flags, "Flags", &unfold_flags))
				{
					m_widgets.doButton(nv::Rect(), "Display Triangles", &(Parameters::getInstance()->g_draw_triangles));
					m_widgets.doButton(nv::Rect(), "Display Octree", &(Parameters::getInstance()->g_draw_cells));
					m_widgets.doButton(nv::Rect(), "Wireframe", &(Parameters::getInstance()->g_solid_wireframe));
					m_widgets.doButton(nv::Rect(), "Cull", &(Parameters::getInstance()->g_culling));
					m_widgets.doButton(nv::Rect(), "Flying camera", &(Parameters::getInstance()->g_controls));
					//m_widgets.doButton(nv::Rect(), "Display textures", &(Parameters::getInstance()->g_textured_data));
					//m_widgets.doButton(nv::Rect(), "Display background", &(skybox));
					m_widgets.doButton(nv::Rect(), "Display transitions", &transition_cells_displayed);
					m_widgets.doButton(nv::Rect(), "LoD Radial", &(Parameters::getInstance()->g_radial_length));
					m_widgets.doButton(nv::Rect(), "Ground truth", &(Parameters::getInstance()->g_ground_truth));
					m_widgets.doButton(nv::Rect(), "Regular grid", &(Parameters::getInstance()->g_regular));
					
					m_widgets.endPanel();
				}
				
				if(m_widgets.beginPanel(r_actions, "Actions", &unfold_actions))
				{
					m_widgets.doButton(nv::Rect(), "Read data from texture", &(Parameters::getInstance()->g_fromtexture));
					m_widgets.doButton(nv::Rect(), "Capture", &(Parameters::getInstance()->g_capture.enabled));
					m_widgets.doButton(nv::Rect(), "Freeze", &(Parameters::getInstance()->g_geometry.freeze));
					m_widgets.endPanel();
				}

				if(m_widgets.doButton(nv::Rect(), "Write Viewpoint"))
				{
					if (Parameters::getInstance()->g_controls)
						write_quatPoint(cam);
					else
						write_viewPoint();
				}
				if(m_widgets.doButton(nv::Rect(), "Load Viewpoint"))
				{
					if (Parameters::getInstance()->g_controls)
						load_quatPoint(cam);
					else
						load_viewPoint();
				}

				sprintf(tmp, "Camera rotation %.3f", cam_rotate);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 0.f, CAM_ROTATE_MAX, &cam_rotate);
				sprintf(tmp, "Camera speed %.2f", cam_speed);
				m_widgets.doLabel(nv::Rect(), tmp);
				m_widgets.doHorizontalSlider(nv::Rect(0,0, 200, 0), 0.f, CAM_SPEED_MAX, &cam_speed);
			}
		}
		
		m_widgets.endGroup();
		m_widgets.end();
	}
    
	int draw( )
	{
		testParameters();
		
		testMovement();
			
		if (animate)
		{
			Parameters::getInstance()->g_time_elapsed += 0.02;
			//Parameters::getInstance()->g_time_elapsed += gpu_time / 1000.0;
		}
		
		GLint64 start; glGetInteger64v(GL_TIMESTAMP, &start);
		window_draw();
		GLint64 stop; glGetInteger64v(GL_TIMESTAMP, &stop); // Nanoseconds
		
		double cpu_time = (stop - start) - sync_cell_cull - sync_count_triangles;
		cpu_time /= 1000; // Microseconds
		GUI( cpu_time );  
		
		/** Screen Recording **/
		if (Parameters::getInstance()->g_capture.enabled && frame%2 == 0) 
		{
                        char buf[256];
			sprintf (buf, "capture_%02i_%09i", Parameters::getInstance()->g_capture.count, Parameters::getInstance()->g_capture.frame);
                        std::string str = std::string(CAPTURE_PATH()) /*+ currentDateTime() + "_"*/ + std::string(buf) + ".bmp";
			gk::writeFramebuffer(str.c_str());
			++(Parameters::getInstance()->g_capture.frame);
			Parameters::getInstance()->g_capture.enabled = !Parameters::getInstance()->g_capture.enabled;
		}

		present();
             
		frame++;
		
		if (plot)
		{
			//frame++;
			
			/*if (frame == 5000)
				animate = false;
			if (frame == 10000)
				animate = true;
			if (frame == 20000)
				exit(0);*/
			
			fprintf(plotfd, "%d \t\t %d \t\t %d \t\t %d \t\t %d \t\t %lf \t\t %lf \t\t %lf \t\t %lf \t\t %lf \t\t %lf \t\t %lf \t\t %lf\n",
					
					frame,
					queryResult_lod,
					queryResult_regular,
					queryResult_transition,
					triangles_regular+triangles_transition,
					
					gpu_lod_time / 1000.0,
					gpu_cull_time / 1000.0,
					gpu_render_time_regular / 1000.0,
					gpu_render_time_transition / 1000.0,
					gpu_shading_time / 1000.0,
		
					gpu_lod_time / 1000.0 +
					gpu_cull_time / 1000.0 +
					gpu_render_time_regular / 1000.0 +
					gpu_render_time_transition / 1000.0,
		
					gpu_time,
		
					cpu_time
			);
		}
		
		return 1;
	}
};

int main( int argc, char **argv )
{
	if (argc < 3)
	{
		printf("Usage : %s <data_file> <type> [size]\n\n Type: \t 1 - .raw files\n Size:\t default = 256\n", argv[0]);
		return 0;
	}
	Vizo app(argc, argv);
	app.run();

	return 0;
}