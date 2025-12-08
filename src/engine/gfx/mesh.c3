module engine::gfx;

import std::io;//TODO: Remove
import opengl::gl;
import glfw;

struct Mesh {
    uint vao;
    int count;
}

fn Mesh Mesh.make(self, float[] verticies, int floats_stride) {
    uint vao;
    uint vbo;

    io::printfn("Test: [%s]", verticies);
    gl::genVertexArrays(1, &vao);
    gl::bindVertexArray(vao);

    gl::genBuffers(1, &vbo);
    gl::bindBuffer(GL_ARRAY_BUFFER, vbo);

    gl::bufferData(
	GL_ARRAY_BUFFER,
	verticies.len * float.sizeof,
	verticies,
	GL_STATIC_DRAW);

    gl::enableVertexAttribArray(0);
    gl::vertexAttribPointer(
	0,
	3,
	GL_FLOAT,
	(GLboolean)false,
	floats_stride * float.sizeof,
	(void*)0);


    io::printfn("count: %d stride: %d", verticies.len, floats_stride);
    self = {.vao = vao, .count = verticies.len / floats_stride};
    return self;
}

fn void Mesh.draw(self) {
    gl::bindVertexArray(self.vao);
    gl::drawArrays(GL_TRIANGLES, 0, self.count);
}
