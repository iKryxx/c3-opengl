module engine::platform;

import engine::core;
import opengl::gl;
import glfw;

faultdef GLFW_INIT_ERROR;
faultdef GLFW_WINDOW_CREATE_ERROR;
faultdef GL_INIT_ERROR;

struct WindowConfig {
    int width;
    int height;
    ZString title;
    bool vsync;
}

GlfwWindow* g_window = null;
WindowConfig g_config;

fn void glfw_error_callback(int code, char* message) @private {
    core::log(core::LOGLEVEL_ERROR, "(%d): %s", code, message);
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

    if(catch excuse = init_gl()) {
	return GL_INIT_ERROR?;
    }

    gl::frontFace(GL_CCW);
    gl::enable(GL_DEPTH_TEST);
    gl::depthFunc(GL_LEQUAL);
    gl::enable(GL_CULL_FACE);
    int fbw;
    int fbh;
    glfw::getFramebufferSize(g_window, &fbw, &fbh);
    gl::viewport(0, 0, fbw, fbh);
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
    core::log(core::LOGLEVEL_INFO, "Renderer: %s", (ZString)renderer);
    core::log(core::LOGLEVEL_INFO, "Version: %s", (ZString)version);
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
    }
    glfw::terminate();
}
