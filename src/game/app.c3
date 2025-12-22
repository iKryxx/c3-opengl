module game::app;

import shader;
import std::io;
import glfw;
import engine::platform;
import engine::gfx;
import engine::math;
import game::world;
import opengl::gl;
import engine::core;
import game::settings;
import game::camera;


World world;
Shader c_shader;
Texture[100] c_textures;
TextureArray arr;
GLfloat delta_time = 0.0f;
GLfloat last_frame = 0.0f;
Camera cam;

<* 
 Keyboard input callback that updates the engine key state.
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

<*
 Mouse cursor callback that updates accumulated deltas for look input.
*>
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

<*
 Loads block textures into a texture array for the voxel shader.
*>
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

<*
 Applies settings that can be changed at runtime.
*>
fn void update_settings() {
	if(settings::should_update) {
		// V-SYNC
		platform::set_vsync(settings::game_settings[Setting.VSYNC].bval);
		// TODO: FOV
		// TODO: Sensitivity
	}
	settings::should_update = false;
}

<*
 Updates delta time used for movement.
*>
fn void update_dt() {
	GLfloat current_frame = (GLfloat)glfw::getTime();
	delta_time = current_frame - last_frame;
	last_frame = current_frame;
}

<*
 Initializes camera defaults for gameplay.
*>
fn void init_camera_defaults() {
	cam.position = {8.0f, world::CHUNK_HEIGHT, -5.0f};
	cam.speed = 4.175;
	cam.sensitivity = 2;
}

<*
 Performs per-frame updates before rendering.
*>
fn void begin_frame() {
	update_dt();
	cam.update();
	platform::poll_events();
	world::update_world(&world, cam.position);
}

<*
 Updates framebuffer state and returns the current aspect ratio.
*>
fn bool prepare_framebuffer(float *aspect) {
	platform::update_framebuffer_size();
	if(platform::g_config.fb_height == 0) return false;
	*aspect = (float)platform::g_config.fb_width / (float)platform::g_config.fb_height;
	return true;
}

<*
 Builds the camera view matrix for the current frame.
*>
fn Mat4f build_view_matrix() {
	Vec3f up = {0.0f, 1.0f, 0.0f};
	return mat4::look_at(cam.position, cam.get_look_at_target(), up);
}

<*
 Binds the voxel shader and uploads common uniforms.
*>
fn void bind_scene_shader(Mat4f view, Mat4f proj, Mat4f model) {
	c_shader.use();
	arr.bind(0);
	c_shader.set_float("u_Textures", 0);
	c_shader.set_mat4("view", view);
	c_shader.set_mat4("proj", proj);
	c_shader.set_mat4("model", model);
}

<*
 Draws all resident chunks, generating meshes as needed.
*>
fn void draw_world() {
	for(int i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		if(!world::chunk_in_render_range(chunk, cam.position)) continue;
		if(chunk.dirty) chunk.generate_chunk_mesh(&world);
		chunk.dirty = false;
		chunk.mesh.draw();
	}
}

<*
 Handles non-movement shortcuts such as quit/fullscreen.
*>
fn void handle_shortcuts() {
	if(platform::is_key_down(platform::Key.KEY_ESCAPE)) {
		glfw::setWindowShouldClose(platform::g_window, 1);
	}
	if(platform::was_key_pressed(platform::Key.KEY_F11)) {
		platform::toggle_fullscreen();
	}
}

<*
 Aggregates movement input into a single direction vector.
*>
fn Vec3f collect_movement_input() {
	Vec3f movement = {};
	if(platform::is_key_down(platform::Key.KEY_W)) movement += cam.forward;
	if(platform::is_key_down(platform::Key.KEY_A)) movement += cam.right;
	if(platform::is_key_down(platform::Key.KEY_S)) movement -= cam.forward;
	if(platform::is_key_down(platform::Key.KEY_D)) movement -= cam.right;
	if(platform::is_key_down(platform::Key.KEY_SPACE)) movement.y += 1;
	if(platform::is_key_down(platform::Key.KEY_LSHIFT)) movement.y -= 1;
	return movement;
}

<*
 Applies mouse delta to the camera orientation.
*>
fn void apply_mouse_look() {
	float[<2>] m_d = platform::mouse_delta();
	cam.direction_tick(m_d);
}

<*
 Advances the camera position with speed and delta time.
*>
fn void apply_movement(Vec3f movement) {
	cam.position += movement *
		(Vec3f){cam.speed, cam.speed, cam.speed} *
		(Vec3f){delta_time, delta_time, delta_time};
}

<*
 Main loop; handles updates, rendering, and input.
*>
fn int m_loop() {
	gl::enable(GL_DEPTH_TEST);
	gl::depthFunc(GL_LESS);
	gl::depthMask(GL_TRUE);
	init_camera_defaults();
	world::update_world(&world, cam.position);

long fov = settings::game_settings[Setting.FOV].ival;
	while(!platform::should_close()) {
		begin_frame();

		gfx::clear();

		float aspect = 0.0f;
		if(!prepare_framebuffer(&aspect)) {
			platform::input_frame_reset();
			continue;
		}

		Mat4f proj = mat4::perspective(math::radians(fov), aspect, -1, 1);
		Mat4f model = mat4::identity();
		Mat4f view = build_view_matrix();

		bind_scene_shader(view, proj, model);
		draw_world();

		handle_shortcuts();
		apply_mouse_look();
		apply_movement(collect_movement_input());

		platform::swap_buffers();
		platform::input_frame_reset();
	}
	return 0;
}

<*
 Initializes the engine and enters the main loop.
*>
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

	world = world::generate_world();

	int exit_code = m_loop();

	world::unload_chunk(&world);

	return exit_code;
}
