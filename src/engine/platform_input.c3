module engine::platform;

import opengl::gl;
import glfw;

import std::io;
import std::math;

const int KEY_COUNT = 512;

bool[KEY_COUNT] g_keys_down;
bool[KEY_COUNT] g_keys_pressed;
bool[KEY_COUNT] g_keys_released;

float g_mouse_x = 0;
float g_mouse_y = 0;
float g_mouse_dx = 0;
float g_mouse_dy = 0;

bool g_raw_mouse = false;
bool g_first_mouse = true;

alias On_key_cb = fn void(GlfwWindow* window,
			  int key,
			  int sc,
			  int action,
			  int mods);

alias On_mouse_cb = fn void(GlfwWindow* window,
			    double xpos,
			    double ypos);


fn void init_input_callbacks(GlfwWindow* window,
			     On_key_cb okcb,
			     On_mouse_cb omcb
) {
    glfw::setKeyCallback(window, okcb);
    glfw::setCursorPosCallback(window, omcb);
}


<*
 @require (int)key >= 0, (int)key < KEY_COUNT
*>
fn bool is_key_down(Key key) {
    int k = (int)key;
    return g_keys_down[k];
}

<*
 @require (int)key >= 0, (int)key < KEY_COUNT
*>
fn bool was_key_pressed(Key key) {
    int k = (int)key;
    return g_keys_pressed[k];
}

<*
 @require (int)key >= 0, (int)key < KEY_COUNT
*>
fn bool was_key_released(Key key) {
    int k = (int)key;
    return g_keys_released[k];
}

fn float[<2>] mouse_position() {
    return {g_mouse_x, g_mouse_y};
}

fn float[<2>] mouse_delta() {
    return {g_mouse_dx, g_mouse_dy};
}

fn void input_frame_reset() {
    for(int i = 0; i < KEY_COUNT; ++i) {
	g_keys_pressed[i] = false;
	g_keys_released[i] = false;
    }
    g_mouse_dx = 0;
    g_mouse_dy = 0;
}

fn void set_raw_mouse_mode(bool enabled) {
    g_raw_mouse = enabled;

    const int GLFW_CURSOR = 0x00033001;
    const int GLFW_CURSOR_DISABLED = 0x00034003;
    const int GLFW_CURSOR_NORMAL = 0x00034001;

    glfw::setInputMode(g_window,
		       GLFW_CURSOR,
		       enabled ? GLFW_CURSOR_DISABLED : GLFW_CURSOR_NORMAL);
    g_first_mouse = true;
}
