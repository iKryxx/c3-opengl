# Repository Guidelines

## Project Structure & Module Organization
- `src/main.c3` is the entry point; `src/game` runs the loop and input callbacks; `src/engine` holds platform, math, and gfx modules; `lib` provides vendored C3 libraries for OpenGL (`opengl.c3l`) and GLFW (`glfw.c3l`).
- Build artifacts live in `build/`; place future assets in `resources/`; keep any test helpers in `test/` mirroring the source module layout.

## Build, Test, and Development Commands
- `c3c build` — compile the project per `project.json`, writing binaries to `build/` and honoring dependencies from `lib/`.
- `c3c run opengl_test` — build (if needed) and run the executable target defined in `project.json`.
- `c3c fmt src/**/*.c3` — format source files before sending changes (run selectively if your shell does not expand `**`).

## Coding Style & Naming Conventions
- Use C3 modules (`module engine::gfx;`) and keep imports minimal and explicit.
- Prefer lower_snake_case for functions/variables, PascalCase for types (`WindowConfig`, `Vec3f`), and ALL_CAPS for constants/enum-like values (`GL_DEPTH_TEST`).
- Indent with tabs or 4 spaces consistently; brace style follows K&R (`fn void clear() { ... }`).
- Use doc-style block comments `<* ... *>` for behavioral notes and `//` for short inline context; keep lines under ~100 chars.

## Testing Guidelines
- There are no automated tests yet. Add small, focused C3 test modules under `test/` that mirror the source namespaces.
- Include assertions around math helpers, shader setup, and input handling; prefer deterministic data over real window events.
- Until a test runner is added, at minimum `c3c build` must pass and `c3c run opengl_test` should be smoke-tested for new features.

## Commit & Pull Request Guidelines
- Use concise, imperative commits (e.g., `Add cube MVP matrix wiring`, `Fix mouse delta reset`).
- For PRs, include a short summary, key testing notes, and any linked issues; attach screenshots or short clips for rendering or input changes.
- Ensure builds are clean, formatting is applied, and new modules are wired into `project.json` before requesting review.
