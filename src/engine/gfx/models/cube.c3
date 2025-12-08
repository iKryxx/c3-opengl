module engine::gfx;

import engine::math;

const ZString CUBE_VS =
`
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUV;

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

out vec3 vNormal;
out vec2 vUV;

void main() {
    vNormal = aNormal;
    vUV = aUV;
    gl_Position = proj * view * model * vec4(aPos, 1.0);
}
`;

const ZString CUBE_FS =
`
#version 330 core
in vec3 vNormal;
in vec2 vUV;

out vec4 FragColor;

uniform sampler2D u_Tex;

void main() {
    vec3 light = normalize(vec3(0.8,0.9,1.0));
    float d = max(dot(vNormal, light), 0.2);

    vec3 texColor = texture(u_Tex, vUV).rgb;
    FragColor = vec4(texColor * d, 1.0);
}
`;

const float[*] CUBE_VERTICIES @private = {
    // Positions (x,y,z) normals(x, y, z) uv(x, y)

    // FRONT face (z = +0.5, normal = 0,0,1)
    -0.5, -0.5,  0.5,   0,0,1,   0,0,
    0.5, -0.5,  0.5,   0,0,1,   1,0,
    0.5,  0.5,  0.5,   0,0,1,   1,1,
    -0.5,  0.5,  0.5,   0,0,1,   0,1,
    
    // BACK (z = -0.5, normal = 0,0,-1)
    -0.5, -0.5, -0.5,   0,0,-1,   1,0,
    0.5, -0.5, -0.5,   0,0,-1,   0,0,
    0.5,  0.5, -0.5,   0,0,-1,   0,1,
    -0.5,  0.5, -0.5,   0,0,-1,   1,1,
    
    // LEFT (x = -0.5, normal = -1,0,0)
    -0.5, -0.5, -0.5,   -1,0,0,   0,0,
    -0.5, -0.5,  0.5,   -1,0,0,   1,0,
    -0.5,  0.5,  0.5,   -1,0,0,   1,1,
    -0.5,  0.5, -0.5,   -1,0,0,   0,1,
    
    // RIGHT (x = +0.5, normal = 1,0,0)
    0.5, -0.5, -0.5,   1,0,0,   1,0,
    0.5, -0.5,  0.5,   1,0,0,   0,0,
    0.5,  0.5,  0.5,   1,0,0,   0,1,
    0.5,  0.5, -0.5,   1,0,0,   1,1,
    
    // TOP (y = +0.5, normal = 0,1,0)
    -0.5,  0.5, -0.5,   0,1,0,   0,1,
    0.5,  0.5, -0.5,   0,1,0,   1,1,
    0.5,  0.5,  0.5,   0,1,0,   1,0,
    -0.5,  0.5,  0.5,   0,1,0,   0,0,
    
    // BOTTOM (y = -0.5, normal = 0,-1,0)
    -0.5, -0.5, -0.5,   0,-1,0,   0,0,
    0.5, -0.5, -0.5,   0,-1,0,   1,0,
    0.5, -0.5,  0.5,   0,-1,0,   1,1,
    -0.5, -0.5,  0.5,   0,-1,0,   0,1,
};

const uint[*] CUBE_INDICES = {
    0,2,1,   2,0,3,         // front
    4,5,6,   6,7,4,         // back
    8,10,9,  10,8,11,       // left
    12,13,14, 14,15,12,     // right
    16,17,18, 18,19,16,     // top
    20,22,21, 22,20,23      // bottom
};


fn Mesh Mesh.make_cube(self) {
    return self.make(&CUBE_VERTICIES, &CUBE_INDICES, 8);  
}
