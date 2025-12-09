module game::app;

import shader;
import std::io;
import glfw;
import engine::platform;
import engine::gfx;
import engine::math;

import opengl::gl;
import engine::core;

Shader c_shader;
Texture[100] c_textures;
TextureArray arr;

<*
 @require key >= 0, key < platform::KEY_COUNT
*>
fn void key_input_callback(GlfwWindow* window,
			   int key,
			   int sc,
			   int action,
			   int mods
) {
    if (action == glfw::PRESS) {
	platform::g_keys_down[key] = true;
	platform::g_keys_pressed[key] = true;
    }
    else if(action == glfw::RELEASE) {
	platform::g_keys_down[key] = false;
	platform::g_keys_released[key] = true;
    }
}

fn void cursor_input_callback(GlfwWindow* window,
			      double xpos,
			      double ypos
) {
    if(platform::g_first_mouse) {
	platform::g_mouse_x = (float) xpos;
	platform::g_mouse_y = (float) ypos;
	platform::g_first_mouse = false;
	return;
    }

    float new_x = (float)xpos;
    float new_y = (float)ypos;

    platform::g_mouse_dx = new_x - platform::g_mouse_x;
    platform::g_mouse_dy = new_y - platform::g_mouse_y;

    platform::g_mouse_x = new_x;
    platform::g_mouse_y = new_y;
}

fn void load_textures() {
   
    String[] paths = {
	"assets/blocks/dirt.tga",
	"assets/blocks/grass_top.tga",
	"assets/blocks/grass_side.tga"
    };

    arr = gfx::texture_array_create(16, 16, paths.len);
    for(int i = 0; i < paths.len; i++) {
	String curr = paths[i];

	Texture tex = gfx::texture_load_tga(curr);
	c_textures[i] = tex;
	arr.set(i, tex.pixels);
	
    }
}

fn int m_loop(WindowConfig cfg) {
    Mesh cube;
    cube = cube.make_cube({2, 2, 2, 2, 1, 0});
    
    float angle = 0.0f;

    gl::enable(GL_DEPTH_TEST);

    Vec3f eye = {0.0f, 2.0f, -5.0f};
    while(!platform::should_close()) {
	int[<2>] framebuffer_size = platform::framebuffer_size();

	platform::poll_events();
	gfx::clear();

	
	Vec3f center = {0.0f, 0.0f, 0.0f};
	Vec3f up = {0.0f, 1.0f, 0.0f};

	// TODO: Structurise this
	Mat4f view = mat4::look_at(eye, center, up);
	
	float aspect = (float)cfg.width / (float)cfg.height;
	Mat4f proj = mat4::perspective(70 * 0.01745329251, aspect, 0.1, 1000);
	Mat4f model = mat4::rotation_y(angle);

	c_shader.use();
	arr.bind(0);
	c_shader.set_float("u_Textures", 0);
	c_shader.set_mat4("view", view);
	c_shader.set_mat4("proj", proj);
	c_shader.set_mat4("model", model);

	
	cube.draw();
	angle += 0.0001f;
	
	// TODO: RENDERING

	if(platform::is_key_down(platform::Key.KEY_ESCAPE)) {
	    glfw::setWindowShouldClose(platform::g_window, 1);
	}

	platform::swap_buffers();
	platform::input_frame_reset();
    }
    return 0;
}

fn int start(WindowConfig cfg) {
    if(catch excuse = platform::init(cfg)) {
	io::eprintfn("Failed to initialize function: %s", excuse);
	return 1;
    }

    gfx::set_clear_color(0.1, 0.15, 0.3, 1.0);
    
    c_shader = shader::create(&gfx::CUBE_VS, &gfx::CUBE_FS)!!;
    c_shader.use();
    platform::init_input_callbacks(platform::g_window,
				   &key_input_callback,
				   &cursor_input_callback);

    load_textures();
    int exit_code = m_loop(cfg);
    
    
    return exit_code;
}
