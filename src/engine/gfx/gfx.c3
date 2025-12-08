module engine::gfx;

import opengl::gl;
import glfw;
import engine::core;
import std::io;

struct Texture {
    uint id;
    int width;
    int height;
    int components;
}

struct TGAHeader @packed @nopadding {
    char id_length;
    char color_map_type;
    char data_type;

    ushort color_map_origin;
    ushort color_map_length;
    char color_map_depth;

    ushort origin_x;
    ushort origin_y;
    ushort width;
    ushort height;

    char pixel_depth;
    char image_desc;
}

/*
id_length: 0,
color_map_type: 0,
data_type: 2,
color_map_origin: 0, 0,
color_map_type: 0, 0,
color_map_depth: 0, 0,
origin_x: 0, 0,
origin_y: 0, 16,
width: 0, 16,
height: 0, 32,
pixel_depth: 40, 92, 133, 185, 255, 74, 108, 150, 255, 74, 108, 150, 255, 58, 85, 121, 255, 58, 85, 121, 255, 92, 133, 185, 255, 74, 108, 150, 255, 74, 108, 150, 255, 58, 85, 121, 255, 58, 85, 121, 255, 41, 61, 89, 255, 58, 85, 121, 255, 58, 85, 121, 255, 92, 133, 185, 255, 58, 85, 121, 255, 92, 133, 185, 255, 58, 85, 121, 255, 74, 108, 150, 255, 41, 61, 89, 255, 58, 85, 121, 255, 58, 85, 121, 255, 74, 108, 150, 255, 135, 135,
*/

fn char[]? read_file(String filename, char[] buffer)
{
    File file = file::open(filename, "r")!;

    defer (void)file.close();

    file.read(buffer)!;
    return buffer; // return a buffer result
}

fn Texture texture_load_tga(String path) {
    core::log(core::LOGLEVEL_LOG, "Begin loading texture: %s", path);
    char[4096] bytes;
    if(catch excuse = read_file(path, &bytes)) {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: %s", path, excuse);
	return {.id = 0};
    }

    //core::log(core::LOGLEVEL_LOG, "%s", bytes);
    
    if(bytes.len < 18) {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: file to small", path);
	return {.id = 0};
    }

    
    TGAHeader *hdr = (TGAHeader*)(void*)bytes[..];

    int width = hdr.width;
    int height = hdr.height;
    int bpp = hdr.pixel_depth;
    
    if(!(bpp == 24 || bpp == 32)) {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: unsupported bpp %d", path, bpp);
	return {.id = 0};
    }

    if (hdr.data_type != 2) // 2 = uncompressed true-color
    {
        core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: only uncompressed RGB(A) supported", path);
        return {.id = 0};
    }

    int pixel_size = bpp / 8;

    int image_size = width * height * pixel_size;

    int offset = 18 + hdr.id_length;

    if(offset + (long)image_size > bytes.len)
    {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: image data out of bounds", path);
        return {.id = 0};
    }

    char[4096] pixels;

    for(int i = 0; i < image_size; i += pixel_size) {
	char b = bytes[offset + i + 0];
	char g = bytes[offset + i + 1];
	char r = bytes[offset + i + 2];

	if(pixel_size == 3) {
	    pixels[i + 0] = r;
	    pixels[i + 1] = g;
	    pixels[i + 2] = b;
	} else {
	    char a = bytes[offset + i + 3];
	    pixels[i + 0] = r;
	    pixels[i + 1] = g;
	    pixels[i + 2] = b;
	    pixels[i + 3] = a;
	}
    }

    // Upload to GL

    uint tex;
    gl::genTextures(1, &tex);

    gl::bindTexture(GL_TEXTURE_2D, tex);
    gl::texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    gl::texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    uint format = (pixel_size == 4) ? GL_RGBA : GL_RGB;

    gl::texImage2D(
	GL_TEXTURE_2D, 0,
	format,
	width, height, 0,
	(GLenum)format,
	GL_UNSIGNED_BYTE,
	pixels[..]
    );

    return {
	.id = tex,
	.width = width,
	.height = height,
	.components = pixel_size
    };
}

fn void Texture.use(&self, int slot) {
    gl::activeTexture((GLenum)(GL_TEXTURE0 + slot));
    gl::bindTexture(GL_TEXTURE_2D, self.id);
}

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
