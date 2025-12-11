module engine::platform;

import engine::core;
import opengl::gl;
import glfw;
import game::settings;
import engine::core::fs;
import std::io;

faultdef GLFW_INIT_ERROR;
faultdef GLFW_WINDOW_CREATE_ERROR;
faultdef GL_INIT_ERROR;

struct WindowConfig {
    int width;
    int height;
    int fb_width;
    int fb_height;
    ZString title;
    bool vsync;
    bool fullscreen;
    int last_win_x;
    int last_win_y;
    int last_win_w;
    int last_win_h;
}

GlfwWindow* g_window = null;
WindowConfig g_config;

fn void glfw_error_callback(int code, char* message) @private {
    core::error("(%d): %s", code, message);
}


<*
 Initializes GLFW and OpenGL
 @param cfg: `The Window Config to be used`
 @require cfg.width > 0, cfg.height > 0, cfg.title != ""
 @return? GLFW_INIT_ERROR, GLFW_WINDOW_CREATE_ERROR, GL_INIT_ERROR
*>
fn void? init(WindowConfig cfg) {
    g_config = cfg;

    // Setup engine config
    core::g_cfg = {};
    if($feature(DEBUG)) {
	core::g_cfg.log_level |=
	core::LOGLEVEL_LOG | core::LOGLEVEL_INFO | core::LOGLEVEL_WARNING | core::LOGLEVEL_ERROR;
    } else {
	core::g_cfg.log_level |= core::LOGLEVEL_WARNING | core::LOGLEVEL_ERROR;
    }

    init_settings()!;
    
    glfw::setErrorCallback((GlfwErrorFn)&glfw_error_callback);

    if(glfw::init() == 0) {
	return GLFW_INIT_ERROR?;
    }

    glfw::defaultWindowHints();

    const int GLFW_CONTEXT_VERSION_MAJOR = 0x00022002;
    const int GLFW_CONTEXT_VERSION_MINOR = 0x00022003;
    const int GLFW_OPENGL_PROFILE =        0x00022008;
    const int GLFW_OPENGL_CORE_PROFILE =   0x00032001;

    
    glfw::windowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw::windowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw::windowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    g_window = glfw::createWindow(
	cfg.width,
	cfg.height,
	cfg.title,
	null,
	null
    );

    
    if(g_window == null) {
	glfw::terminate();
	return GLFW_WINDOW_CREATE_ERROR?;
    }



    glfw::makeContextCurrent(g_window);
    glfw::swapInterval(cfg.vsync ? 1 : 0);
    glfw::setInputMode(g_window, glfw::CURSOR, glfw::CURSOR_DISABLED);
    if(catch excuse = init_gl()) {
	return GL_INIT_ERROR?;
    }

    gl::frontFace(GL_CCW);
    gl::enable(GL_DEPTH_TEST);
    gl::depthFunc(GL_LEQUAL);
    gl::enable(GL_CULL_FACE);

    glfw::getFramebufferSize(g_window, &g_config.fb_width, &g_config.fb_height);
    gl::viewport(0, 0, g_config.fb_width, g_config.fb_height);
}

<*
 Inititalizes OpenGL.
*>
fn void? init_gl()
{
    if(catch excuse = opengl::init((GLLoadFn)&glfw::getProcAddress)) {
	return excuse?;
    }

    char* renderer = gl::getString(gl::GL_RENDERER);
    char* version = gl::getString(gl::GL_VERSION);
    core::info("Renderer: %s", (ZString)renderer);
    core::info("Version: %s", (ZString)version);
}

fn void? init_settings() {
    Ini_file? f = fs::ini_parse("settings.ini");
    if(catch excuse = f) {
	if(excuse == io::FILE_NOT_FOUND) {
	    settings::game_settings.write_ini("settings.ini")!;
	    return;
	} else {
	    return excuse?;
	}
    }
    
    settings::game_settings.parse_ini(&f)!;
    f.free();
}

<*
 Polls GLFW Events. Calls `glfw::pollEvents()` internally.
*>
fn void poll_events() {
    glfw::pollEvents();
}

<*
 Swaps draw buffers. Calls `glfw::swapBuffers()` internally. 
*>
fn void swap_buffers() {
    glfw::swapBuffers(g_window);
}

fn void update_framebuffer_size() {
    if(g_window == null) return;

    int fbw;
    int fbh;
    glfw::getFramebufferSize(g_window, &fbw, &fbh);
    if(fbw == g_config.fb_width && fbh == g_config.fb_height) return;

    g_config.fb_width = fbw;
    g_config.fb_height = fbh;
    glfw::getWindowSize(g_window, &g_config.width, &g_config.height);

    gl::viewport(0, 0, g_config.fb_width, g_config.fb_height);
}

<*
 Checks, if the application should terminate or not

 @return "true if the application should terminate, false if not."
*>
fn bool should_close() {
    if(g_window == null) return true;
    return glfw::windowShouldClose(g_window) != 0;
}

<*
 Retrieves the size of the framebuffer.
 @return "a vector of length 2, x is width, y is height"
 @deprecated
*>
fn int[<2>] framebuffer_size() {
    int width;
    int height;
    if(g_window == null) return {0, 0};
    glfw::getFramebufferSize(g_window, &width, &height);
    return {width, height};
}

<*
 destroys the window and terminates GLFW.
*>
fn void shutdown() {
    if(g_window != null) {
	glfw::destroyWindow(g_window);
	g_window = null;
    }
    glfw::terminate();
}

fn void toggle_fullscreen() {
    if(!g_config.fullscreen) {
	glfw::getWindowPos(g_window,
			   &g_config.last_win_x,
			   &g_config.last_win_y);
	glfw::getWindowSize(g_window,
			    &g_config.last_win_w,
			    &g_config.last_win_h);

	GlfwMonitor *monitor = glfw::getPrimaryMonitor(); 
	GlfwVidMode *mode = glfw::getVideoMode(monitor);
	
	glfw::setWindowMonitor(
	    g_window,
	    monitor,
	    0, 0,
	    mode.width,
	    mode.height,
	    mode.refreshRate
	);

	g_config.width = mode.width;
	g_config.height = mode.height;

	g_config.fullscreen = true;
    } else {
	glfw::setWindowMonitor(
	    g_window,
	    null,
	    g_config.last_win_x,
	    g_config.last_win_y,
	    g_config.last_win_w,
	    g_config.last_win_h,
	    0
	);
	g_config.width = g_config.last_win_w;
	g_config.height = g_config.last_win_h;

	g_config.fullscreen = false;
    }

    update_framebuffer_size();
    
}
