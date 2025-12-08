module engine::math::mat4 {Type};
import engine::math::vec3;
import std::math;


struct Mat4 {
    union {
	struct {
	    Type a1; Type a2; Type a3; Type a4;
	    Type b1; Type b2; Type b3; Type b4;
	    Type c1; Type c2; Type c3; Type c4;
	    Type d1; Type d2; Type d3; Type d4;
	}
	Type[<16>] inner;
    }
}

fn Mat4 identity() {
    return {
	1, 0, 0, 0,
	0, 1, 0, 0,
	0, 0, 1, 0,
	0, 0, 0, 1
    };
}

fn Mat4 zero() {
    return {
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0
    };
}

fn Type Mat4.get(&self, usz i) @operator([]) {
    return self.inner[i];
}

fn Type* Mat4.get_ref(&self, usz i) @operator(&[]) {
    return &self.inner[i];
}

fn void Mat4.set(&self, usz i, Type new_val) @operator([]=) {
    self.inner[i] = new_val;
}

fn Mat4 Mat4.mul(self, Mat4 other) @operator(*) {
    Mat4{Type} res = mat4::zero();

    for(usz col = 0; col < 4; ++col) {
	for(usz row = 0; row < 4; ++row) {
	    Type sum = 0;
	    
	    for(usz k = 0; k < 4; ++k) {
		sum += self[k * 4 + row] * other[col * 4 + k];
	    }

	    res[col * 4 + row] = sum;
	}	
    }
    return res;
}

fn Mat4 translate(Vec3{Type} t) {
    Mat4 m = mat4::identity();
    m[12] = t.x;
    m[13] = t.y;
    m[14] = t.z;
    return m;
}

fn Mat4 scale(Vec3{Type} s) {
    return {
	s.x, 0, 0, 0,
	0, s.y, 0, 0,
	0, 0, s.z, 0,
	0, 0, 0, 1
    };
}

fn Mat4f rotation_x(float angle) {
    float c = math::cos(angle);
    float s = math::sin(angle);

    return {
	1, 0, 0, 0,
	0, c, s, 0,
	0, -s, c, 0,
	0, 0, 0, 1
    };
}


fn Mat4f rotation_y(float angle) {
    float c = math::cos(angle);
    float s = math::sin(angle);

    return {
	c, 0, -s, 0,
	0, 1, 0, 0,
	s, 0, c, 0,
	0, 0, 0, 1
    };
}

fn Mat4f rotation_z(float angle) {
    float c = math::cos(angle);
    float s = math::sin(angle);

    return {
	c, s, 0, 0,
	-s, c, 0, 0,
	0, 0, 1, 0,
	0, 0, 0, 1
    };
}

fn Mat4f perspective(
    float fov_radians,
    float aspect,
    float near,
    float far)
{
    float f = 1.0f / math::tan(fov_radians * 0.5f);

    return {
	f / aspect, 0, 0,                       0,
	0,          f, 0,                       0,
	0,          0, -((far+near)/(near-far)),   -1,
	0,          0, -((2*far*near)/(near-far)), 0
    };
}

fn Mat4f look_at(Vec3f eye, Vec3f target, Vec3f up) {
    Vec3f f = Vec3.normalize(target - eye);
    // Ensure a right-handed basis: right comes from up x forward, not the other way around.
    Vec3f s = Vec3.normalize(up.cross(f));
    Vec3f u = f.cross(s);
    
    Mat4f out = {
	s.x,          u.x,       -f.x,        0,
	s.y,          u.y,       -f.y,        0,
	s.z,          u.z,       -f.z,        0,
	-s.dot(eye), -u.dot(eye), f.dot(eye), 1
    };
    return out;
}
