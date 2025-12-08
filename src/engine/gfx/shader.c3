module shader;

import opengl::gl;
import std::io;
import engine::math;

faultdef SHADER_COMPILATION_FAILED;

struct Shader {
    uint id;
    uint vertex_id;
    uint fragment_id;
}


fn uint? compile(GLenum shadertype, char** src) {
    int id = gl::createShader(shadertype);
    gl::shaderSource(id, 1, src, null);
    gl::compileShader(id);

    int success;
    gl::getShaderiv(id, gl::GL_COMPILE_STATUS, &success);

    if(!success) {
	GLsizei len;
	char[512] infoLog;
	gl::getShaderInfoLog(id, 512, &len, &infoLog);
	io::eprintfn("SHADER ERROR: %s", (String)infoLog[:len]);
	return SHADER_COMPILATION_FAILED?;
    }

    return id;
}

fn Shader? create(char** vert_src, char** frag_src) {
    uint vertex_id = compile(gl::GL_VERTEX_SHADER, vert_src)!;
    uint fragment_id = compile(gl::GL_FRAGMENT_SHADER, frag_src)!;
    uint id = gl::createProgram();

    gl::attachShader(id, vertex_id);
    gl::attachShader(id, fragment_id);
    gl::linkProgram(id);

    return {
	.vertex_id = vertex_id,
	.fragment_id = fragment_id,
	.id = id
    };
}

fn void Shader.delete(&self) {
    gl::detachShader(self.id, self.vertex_id);
    gl::detachShader(self.id, self.fragment_id);

    gl::deleteShader(self.vertex_id);
    gl::deleteShader(self.fragment_id);

    gl::deleteProgram(self.id);
}

fn void Shader.use(&self) {
    gl::useProgram(self.id);
}

fn void Shader.set_mat4(self, ZString name, Mat4f m) {
    int loc = gl::getUniformLocation(self.id, name);
    gl::uniformMatrix4fv(loc, 1, (GLboolean)false, (float[])&m.inner);
}

