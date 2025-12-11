import game::app;
import engine::platform;
fn int main() {
    WindowConfig cfg = {
	.width = 1080,
	.height = 720,
	.title = "BlockGame",
	.vsync = false
    };
    int ret = app::start(cfg);

    return ret;
}
