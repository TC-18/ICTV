uniform float u_time;
 uniform float u_size_tex;
 uniform sampler3D densities;
 	
float getPotential(vec3 position, float t, int lvl) {
	
	float ret = 0;
	float size = 20.0;
	vec3 p = (position-0.5)*size;
	float x = p.x; float y = p.y; float z = p.z;
	float h;float d=(abs(sin(0.5*t))+0.5) * sqrt(x*x+z*z)+0.01; h=y - (10*(sin(d)/d));;
ret = h;
if (ret < 0) ret = 1;
		else ret = 0; 
return ret;

 }
