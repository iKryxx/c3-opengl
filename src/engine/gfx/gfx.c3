module engine::gfx;

import opengl::gl;
import glfw;
import engine::core;
import std::io;

struct Texture {
    int width;
    int height;
    int components;
    char[] pixels;
}

struct TextureArray {
    uint id;
    int width;
    int height;
    int layers;
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

fn char[]? read_file(String filename, char[] buffer) @private
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
	return { };
    }

    if(bytes.len < 18) {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: file to small", path);
	return { };
    }

    
    TGAHeader *hdr = (TGAHeader*)(void*)bytes[..];

    int width = hdr.width;
    int height = hdr.height;
    int bpp = hdr.pixel_depth;
    
    if(!(bpp == 24 || bpp == 32)) {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: unsupported bpp %d", path, bpp);
	return {  };
    }

    if (hdr.data_type != 2) // 2 = uncompressed true-color
    {
        core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: only uncompressed RGB(A) supported", path);
        return {  };
    }

    int pixel_size = bpp / 8;

    int image_size = width * height * pixel_size;

    int offset = 18 + hdr.id_length;

    if(offset + (long)image_size > bytes.len)
    {
	core::log(core::LOGLEVEL_WARNING, "Failed to load texture file %s: image data out of bounds", path);
        return {  };
    }

    char[4096] pixels;
    bool flip_vertical = (hdr.image_desc & 0x20) != 0; // TGA top-left origin flag
    int row_stride = width * pixel_size;

    for(int y = 0; y < height; ++y) {
	int src_y = flip_vertical ? (height - 1 - y) : y;
	int src_base = offset + src_y * row_stride;
	int dst_base = y * row_stride;
	for(int x = 0; x < row_stride; x += pixel_size) {
	    char b = bytes[src_base + x + 0];
	    char g = bytes[src_base + x + 1];
	    char r = bytes[src_base + x + 2];

	    if(pixel_size == 3) {
		pixels[dst_base + x + 0] = r;
		pixels[dst_base + x + 1] = g;
		pixels[dst_base + x + 2] = b;
	    } else {
		char a = bytes[src_base + x + 3];
		pixels[dst_base + x + 0] = r;
		pixels[dst_base + x + 1] = g;
		pixels[dst_base + x + 2] = b;
		pixels[dst_base + x + 3] = a;
	    }
	}
    }

    return {
	.width = width,
	.height = height,
	.components = pixel_size,
	.pixels = &pixels,
    };
    // Upload to GL
    /*  
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
    */
}

fn TextureArray texture_array_create(int width, int height, int layers) {
    uint tex;
    gl::genTextures(1, &tex);

    gl::bindTexture(GL_TEXTURE_2D_ARRAY, tex);

    gl::texParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    gl::texParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    gl::texImage3D(
	GL_TEXTURE_2D_ARRAY, 0,
	GL_RGBA,
	width, height, layers,
	0,
	GL_RGBA,
	GL_UNSIGNED_BYTE,
	null
    );

    return {
	.id = tex,
	.width = width,
	.height = height,
	.layers = layers
    };
}

fn void TextureArray.set(&self, int layer, char[] pixels) {
    gl::bindTexture(GL_TEXTURE_2D_ARRAY, self.id);

    gl::texSubImage3D(
	GL_TEXTURE_2D_ARRAY,
	0,
	0, 0, layer,
	self.width, self.height, 1,
	GL_RGBA,
	GL_UNSIGNED_BYTE,
	pixels
    );
}

fn void TextureArray.bind(&self, int slot) {
    gl::activeTexture((GLenum)(GL_TEXTURE0 + slot));
    gl::bindTexture(GL_TEXTURE_2D_ARRAY, self.id);
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
