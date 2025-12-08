module engine::gfx;

import opengl::gl;
import glfw;

struct Mesh {
    uint vao;
    int count;
}

fn Mesh Mesh.make(self, float[] verticies, uint[] indices, int floats_stride) {
    uint vao;
    uint vbo;
    uint ebo;

    gl::genVertexArrays(1, &vao);
    gl::bindVertexArray(vao);

    gl::genBuffers(1, &vbo);
    gl::bindBuffer(GL_ARRAY_BUFFER, vbo);

    gl::bufferData(
	GL_ARRAY_BUFFER,
	verticies.len * float.sizeof,
	verticies,
	GL_STATIC_DRAW);

    gl::genBuffers(1, &ebo);
    gl::bindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    gl::bufferData(GL_ELEMENT_ARRAY_BUFFER,
        indices.len * uint.sizeof,
        indices,
        GL_STATIC_DRAW);

    GLsizei stride_bytes = floats_stride * float.sizeof;
    
    gl::enableVertexAttribArray(0);
    gl::vertexAttribPointer(
	0, 3, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)0
    );

    gl::enableVertexAttribArray(1);
    gl::vertexAttribPointer(
	1, 3, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)(3 * float.sizeof)
    );

    gl::enableVertexAttribArray(2);
    gl::vertexAttribPointer(
	2, 2, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)(6 * float.sizeof)
    );
    self = {.vao = vao, .count = indices.len};
    return self;
}

fn void Mesh.draw(self) {
    gl::bindVertexArray(self.vao);
    gl::drawElements(GL_TRIANGLES, self.count, GL_UNSIGNED_INT, (void*)0);
}
