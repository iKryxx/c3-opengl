module engine::gfx;

import engine::math;

const ZString CUBE_VS =
`
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;


void main() {
    gl_Position = proj * view * model * vec4(aPos, 1.0);
}
`;

const ZString CUBE_FS =
`
#version 330 core
out vec4 FragColor;

void main() {
    FragColor = vec4(0.8, 0.9, 1.0, 1.0);
}
`;

const float[*] CUBE_VERTICIES @private = {
    // Positions (x,y,z)

    // front
    -0.5, -0.5,  0.5,
    0.5, -0.5,  0.5,
    0.5,  0.5,  0.5,
    -0.5, -0.5,  0.5,
    0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5,
    
    // back
    -0.5, -0.5, -0.5,
    0.5,  0.5, -0.5,
    0.5, -0.5, -0.5,
    -0.5, -0.5, -0.5,
    -0.5,  0.5, -0.5,
    0.5,  0.5, -0.5,
    
    // left
    -0.5, -0.5, -0.5,
    -0.5, -0.5,  0.5,
    -0.5,  0.5,  0.5,
    -0.5, -0.5, -0.5,
    -0.5,  0.5,  0.5,
    -0.5,  0.5, -0.5,
    
    // right
    0.5, -0.5, -0.5,
    0.5,  0.5,  0.5,
    0.5, -0.5,  0.5,
    0.5, -0.5, -0.5,
    0.5,  0.5, -0.5,
    0.5,  0.5,  0.5,
    
    // top
    -0.5,  0.5, -0.5,
    -0.5,  0.5,  0.5,
    0.5,  0.5,  0.5,
    -0.5,  0.5, -0.5,
    0.5,  0.5,  0.5,
    0.5,  0.5, -0.5,
    
    // bottom
    -0.5, -0.5, -0.5,
    0.5, -0.5,  0.5,
    -0.5, -0.5,  0.5,
    -0.5, -0.5, -0.5,
    0.5, -0.5, -0.5,
    0.5, -0.5,  0.5,
};


fn Mesh Mesh.make_cube(self) {
    return self.make(&CUBE_VERTICIES, 3);  
}
