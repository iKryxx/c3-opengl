module game::camera;
import engine::math;
import std::math;
import std::io;

struct Camera {
    Vec3f position;
    float yaw;
    float pitch;
    Vec3f forward;
    Vec3f right;
    float speed;
    float sensitivity;
}

fn void Camera.update(&self) {
    self.forward = {
	math::cos(self.yaw),
	0,
	math::sin(self.yaw)
    };

    self.right = {
	-self.forward.z,
	0,
	self.forward.x
    };
}

fn void Camera.direction_tick(&self, float[<2>] deltas) {
    self.yaw += deltas.x * self.sensitivity / 1000;
    self.pitch -= deltas.y * self.sensitivity / 1000;

    
    if(self.pitch > 89) self.pitch = 89;
    if(self.pitch < -89) self.pitch = -89;
}

fn Vec3f Camera.get_world_direction(&self) {
    return {
	math::cos(self.pitch) * math::cos(self.yaw),
	math::sin(self.pitch),
	math::cos(self.pitch) * math::sin(self.yaw)
    };
}

fn Vec3f Camera.get_world_forward(&self) {
    return self.get_world_direction().normalize();
}

fn Vec3f Camera.get_world_right(&self) {
    return self.get_world_forward().cross((Vec3f){0, 1, 0}).normalize();
}

fn Vec3f Camera.get_world_up(&self) {
    return self.get_world_right().cross(self.get_world_forward());
}

fn Vec3f Camera.get_look_at_target(&self) {
    return self.position + self.get_world_forward();
}

