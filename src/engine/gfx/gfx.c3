module engine::gfx;

import opengl::gl;
import glfw;

<*
 Sets the color which gets drawn when calling `gl::clear(gl::GL_COLOR_BUFFER_BIT);`

 @require r >= 0, r <= 1, g >= 0, g <= 1, b >= 0, b <= 1, a >= 0, a <= 1
*>
fn void set_clear_color(float r, float g, float b, float a) {
    gl::clearColor(r, g, b, a);
}

<*
 Clears then Screen. calls `gl::clear(gl::GL_COLOR_BUFFER_BIT);` internally.
*>
fn void clear() {
    gl::clear(gl::GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}
