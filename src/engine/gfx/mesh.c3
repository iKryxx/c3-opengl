module engine::gfx;

import std::io;
import engine::core;
import opengl::gl;
import glfw;

struct Mesh {
    uint vao;
    uint vbo;
    uint ebo;
    int count;
}

fn void Mesh.regenerate_buffers(&self) {
    if(self.vao == 0) gl::genVertexArrays(1, &self.vao);
    if(self.vbo == 0) gl::genBuffers(1, &self.vbo);
    if(self.ebo == 0) gl::genBuffers(1, &self.ebo);
}

fn void Mesh.make(&self, float[] verticies, uint[] indices, int floats_stride) {
    core::log(" LENGTHSSS %d %d", verticies.len, indices.len);

    self.regenerate_buffers();
    gl::bindVertexArray(self.vao);
    gl::bindBuffer(GL_ARRAY_BUFFER, self.vbo);

    gl::bufferData(
	GL_ARRAY_BUFFER,
	verticies.len * float.sizeof,
	verticies,
	GL_STATIC_DRAW);

    gl::bindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.ebo);
    gl::bufferData(GL_ELEMENT_ARRAY_BUFFER,
        indices.len * uint.sizeof,
        indices,
        GL_STATIC_DRAW);

    GLsizei stride_bytes = floats_stride * float.sizeof;

    /* Position (location = 0) */
    gl::enableVertexAttribArray(0);
    gl::vertexAttribPointer(
	0, 3, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)0
    );

    /* Normals (location = 1) */
    gl::enableVertexAttribArray(1);
    gl::vertexAttribPointer(
	1, 3, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)(3 * float.sizeof)
    );

    /* UV (location = 2) */
    gl::enableVertexAttribArray(2);
    gl::vertexAttribPointer(
	2, 2, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)(6 * float.sizeof)
    );

    /* Texture ID (location = 3) */
    gl::enableVertexAttribArray(3);
    gl::vertexAttribPointer(
	3, 1, GL_FLOAT, (GLboolean)false,
	stride_bytes,
	(void*)(8 * float.sizeof)
    );
    
    self.count = indices.len;
}


fn void Mesh.draw(self) {
    gl::bindVertexArray(self.vao);
    gl::drawElements(GL_TRIANGLES, self.count, GL_UNSIGNED_INT, (void*)0);
}
