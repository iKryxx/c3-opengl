module engine::math::vec3 {Type};
import std::math;

struct Vec3 {
    union {
	struct {
	    Type x;
	    Type y;
	    Type z;
	}
	Type[<3>] inner;
    }
}

fn Type Vec3.get(&self, usz i) @operator([]) {
    return self.inner[i];
}

fn Type* Vec3.get_ref(&self, usz i) @operator(&[]) {
    return &self.inner[i];
}

fn void Vec3.set(&self, usz i, Type new_val) @operator([]=) {
    self.inner[i] = new_val;
}

fn Vec3 Vec3.add(self, Vec3 other) @operator(+) {
    return {self.x + other.x, self.y + other.y, self.z + other.z};
}

fn Vec3 Vec3.sub(self, Vec3 other) @operator(-) {
    return {self.x - other.x, self.y - other.y, self.z - other.z};
}

fn Vec3 Vec3.mul(self, Vec3 other) @operator(*) {
    return {self.x * other.x, self.y * other.y, self.z * other.z};
}

fn Vec3 Vec3.div(self, Vec3 other) @operator(/) {
    return {self.x / other.x, self.y / other.y, self.z / other.z};
}

fn float Vec3.dot(self, Vec3 other) {
    return (float)(self.x * other.x + self.y * other.y + self.z * other.z);
}

fn Vec3 Vec3.cross(self, Vec3 other) {
    return {
	self.y*other.z - self.z*other.y,
        self.z*other.x - self.x*other.z,
        self.x*other.y - self.y*other.x
    };
}

fn float Vec3.length(self) {
    return math::sqrt(self.dot(self));
}

fn Vec3f Vec3.normalize(self) {
    float len = self.length();
    if(len == 0) return (Vec3f){(float)self.x, (float)self.y, (float)self.z};
    return (Vec3f){(float)self.x, (float)self.y, (float)self.z} * (Vec3f){
	.x = 1.0/len,
	.y = 1.0/len,
	.z = 1.0/len};
}
