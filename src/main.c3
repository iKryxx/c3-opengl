import game::app;
import engine::platform;
fn int main() {
    WindowConfig cfg = {
	.width = 800,
	.height = 600,
	.title = "BlockGame",
	.vsync = false
    };
    int ret = app::start(cfg);

    return ret;
}
