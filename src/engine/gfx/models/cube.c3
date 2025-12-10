module engine::gfx;
import engine::core;
import engine::math;

const ZString CUBE_VS =
`
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUV;
layout (location = 3) in float aTexId;

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

out vec3 vNormal;
out vec2 vUV;
out float vTexId;

void main() {
    vNormal = aNormal;
    vUV = aUV;
    vTexId = aTexId;
    gl_Position = proj * view * model * vec4(aPos, 1.0);
}
`;

const ZString CUBE_FS =
`
#version 330 core
in vec3 vNormal;
in vec2 vUV;
in float vTexId;

out vec4 FragColor;

uniform sampler2DArray u_Textures;

void main() {
    int layer = int(vTexId);
    vec3 texColor = texture(u_Textures, vec3(vUV, layer)).rgb;

    vec3 light = normalize(vec3(0.8,0.9,1.0));
    float d = max(dot(vNormal, light), 0.2);

    FragColor = vec4(texColor * d, 1.0);
}
`;

struct CubeTexture {
    union {
	struct {
	    uint front;
	    uint back;
	    uint left;
	    uint right;
	    uint top;
	    uint bottom;
	}
	uint[6] inner;
    }
}

const int CUBE_FLOAT_STRIDE = 9;

const float[*] CUBE_VERTICIES @private = {
    // Positions (x,y,z) normals(x, y, z) uv(x, y) texid(id)

    // FRONT face (z = +0.5, normal = 0,0,1)
    -0.5, -0.5,  0.5,   0,0,1,   0,0,   0, 
     0.5, -0.5,  0.5,   0,0,1,   1,0,   0,
     0.5,  0.5,  0.5,   0,0,1,   1,1,   0,
    -0.5,  0.5,  0.5,   0,0,1,   0,1,   0,
    
    // BACK (z = -0.5, normal = 0,0,-1)
    -0.5, -0.5, -0.5,   0,0,-1,   1,0,   0,
     0.5, -0.5, -0.5,   0,0,-1,   0,0,   0,
     0.5,  0.5, -0.5,   0,0,-1,   0,1,   0,
    -0.5,  0.5, -0.5,   0,0,-1,   1,1,   0,
    
    // LEFT (x = -0.5, normal = -1,0,0)
    -0.5, -0.5, -0.5,   -1,0,0,   0,0,   0,
    -0.5, -0.5,  0.5,   -1,0,0,   1,0,   0,
    -0.5,  0.5,  0.5,   -1,0,0,   1,1,   0,
    -0.5,  0.5, -0.5,   -1,0,0,   0,1,   0,
    
    // RIGHT (x = +0.5, normal = 1,0,0)
    0.5, -0.5, -0.5,   1,0,0,   1,0,   0,
    0.5, -0.5,  0.5,   1,0,0,   0,0,   0,
    0.5,  0.5,  0.5,   1,0,0,   0,1,   0,
    0.5,  0.5, -0.5,   1,0,0,   1,1,   0,
    
    // TOP (y = +0.5, normal = 0,1,0)
    -0.5,  0.5, -0.5,   0,1,0,   0,1,   0,
     0.5,  0.5, -0.5,   0,1,0,   1,1,   0,
     0.5,  0.5,  0.5,   0,1,0,   1,0,   0,
    -0.5,  0.5,  0.5,   0,1,0,   0,0,   0,
    
    // BOTTOM (y = -0.5, normal = 0,-1,0)
    -0.5, -0.5, -0.5,   0,-1,0,   0,0,   0,
     0.5, -0.5, -0.5,   0,-1,0,   1,0,   0,
     0.5, -0.5,  0.5,   0,-1,0,   1,1,   0,
    -0.5, -0.5,  0.5,   0,-1,0,   0,1,   0,
};

const uint[*] CUBE_INDICES @private = {
    0,2,1,   2,0,3,         // front
    4,5,6,   6,7,4,         // back
    8,10,9,  10,8,11,       // left
    12,13,14, 14,15,12,     // right
    16,17,18, 18,19,16,     // top
    20,22,21, 22,20,23      // bottom
};

fn float[CUBE_FLOAT_STRIDE * 4] get_cube_face_vert(int face) {
    //core::log("len: %d\nval: %d", CUBE_VERTICIES.len, face * CUBE_FLOAT_STRIDE  * 4 + CUBE_FLOAT_STRIDE * 4);
    //core::log("Slice before return: %s", CUBE_VERTICIES[face * CUBE_FLOAT_STRIDE  * 4 : CUBE_FLOAT_STRIDE * 4]);

    float[CUBE_FLOAT_STRIDE * 4] ret = CUBE_VERTICIES[face * CUBE_FLOAT_STRIDE  * 4 : CUBE_FLOAT_STRIDE * 4];
    return ret;
}

fn uint[6] get_cube_face_idx(int face) {
    //core::log("Slice before return: %s", CUBE_VERTICIES[face * 6 : 6]);
    uint[6] ret = CUBE_INDICES[face * 6 : 6];

    return ret;
}


fn void Mesh.make_cube(self, CubeTexture texture) {
    float[CUBE_VERTICIES.len] verts = CUBE_VERTICIES;
    uint v_idx = 8;
    
    for(int i = 0; i < texture.inner.len; i++) {
	for(int j = 0; j < 4; j++) {
	    verts[v_idx] = texture.inner[i];
	    v_idx += CUBE_FLOAT_STRIDE; 
	}
    }
    
    self.make(&verts, &CUBE_INDICES, CUBE_FLOAT_STRIDE);  
}
