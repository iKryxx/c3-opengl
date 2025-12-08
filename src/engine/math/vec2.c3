module engine::math::vec2 {Type};
import std::math;

struct Vec2 {
    union {
	struct {
	    Type x;
	    Type y;
	}
	Type[<2>] inner;
    }
}

fn Type Vec2.get(&self, usz i) @operator([]) {
    return self.inner[i];
}

fn Type* Vec2.get_ref(&self, usz i) @operator(&[]) {
    return &self.inner[i];
}

fn void Vec2.set(&self, usz i, Type new_val) @operator([]=) {
    self.inner[i] = new_val;
}

fn Vec2 Vec2.add(self, Vec2 other) @operator(+) {
    return {self.x + other.x, self.y + other.y};
}

fn Vec2 Vec2.sub(self, Vec2 other) @operator(-) {
    return {self.x - other.x, self.y - other.y};
}

fn Vec2 Vec2.mul(self, Vec2 other) @operator(*) {
    return {self.x * other.x, self.y * other.y};
}

fn Vec2 Vec2.div(self, Vec2 other) @operator(/) {
    return {self.x / other.x, self.y / other.y};
}

fn float Vec2.dot(self, Vec2 other) {
    return (float)(self.x * other.x + self.y * other.y);
}

fn float Vec2.length(self) {
    return math::sqrt(self.dot(self));
}

fn Vec2d Vec2.normalize(self) {
    float len = self.length();
    if(len == 0) return (Vec2d){self.x, self.y};
    return (Vec2d){self.x, self.y} * (Vec2d){.x = 1.0/len, .y = 1.0/len};
}


