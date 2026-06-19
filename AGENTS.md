# Repository Guidelines

## Project Structure & Module Organization

This repository is organized around the core NAS3R implementation, scripts, tests, and a web interface. Keep reusable Python code in package modules rather than one-off scripts. Use `scripts/` for command-line utilities and data or rendering workflows, `tests/` for automated checks, `web/backend/` for API/server code, and `web/frontend/` for the browser client. Generated outputs, caches, build artifacts, and large experiment results should stay out of source-controlled code unless they are small fixtures required by tests.

## Build, Test, and Development Commands

Always run pipeline and test in docker container using "docker compose". Use the `nas3r` Docker Compose service as the development environment.

- `docker compose build`: build the CUDA 12.8 GH200/aarch64 development image.
- `docker compose run --rm nas3r pytest`: run the Python test suite.
- `docker compose run --rm nas3r pytest tests/web`: run web backend tests.
- `docker compose run --rm nas3r python -m pytest tests/path/to/test_file.py`: run a focused test file while iterating.
- `docker compose run --rm nas3r npm --prefix web/frontend run dev -- --host 0.0.0.0`: start the Vite development server.
- `docker compose run --rm nas3r npm --prefix web/frontend run build`: build the production frontend bundle.
- `docker compose logs -f`: inspect service logs during local debugging.

Prefer focused commands during development, then run the broader relevant suite before opening a PR.

## NAS3R Pipeline Output Rules

When running NAS3R on user-provided image folders or video frames, output the predicted 3DGS/point cloud artifact directly, preferably as PLY. Do not output rendered PNG images, MP4 videos, preview grids, or other image/video renderings unless the user explicitly asks for rendered views. Treat rendered images and videos as debugging artifacts, not the requested pipeline result.


## Agent Autonomy


Ask the user only when an action is genuinely risky, destructive, ambiguous in a way that could change the requested outcome, or outside the repository's normal development workflow. Examples include deleting non-generated user files, resetting or discarding Git changes, force-pushing, changing secrets or credentials, writing outside approved workspace paths, installing or downloading dependencies that require network access, starting long-running services that consume significant resources, or making product/design choices that cannot be inferred from existing code and requirements.


## Coding Style & Naming Conventions

Follow existing local style. Python code should use 4-space indentation, descriptive snake_case functions and variables, PascalCase classes, and concise type hints where they clarify public interfaces. Keep module names lowercase with underscores. Frontend TypeScript/React code should use PascalCase components, camelCase variables, and colocated component styles when that matches the surrounding files. Avoid broad refactors in feature or bug-fix changes; keep edits scoped to the behavior being changed.

## Testing Guidelines

Tests live under `tests/` and should be named `test_*.py`. Add or update tests when changing parsing, API behavior, data transformations, rendering workflows, or shared utilities. Prefer deterministic fixtures and small sample data over network-dependent tests. For frontend changes, run the frontend build and add component or integration coverage when the project already has a matching test pattern.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects that describe the change, for example `Fix backend asset path handling` or `Add frontend build configuration`. Keep unrelated work in separate commits. Pull requests should include a concise description, the commands run for verification, linked issues when applicable, and screenshots or screen recordings for visible UI changes. Mention any skipped tests, large generated artifacts, or environment assumptions explicitly.

## Security & Configuration Tips

Do not commit secrets, API tokens, private datasets, or machine-specific paths. Put local configuration in ignored environment files and document required variables in the PR or relevant README. Treat generated model outputs and downloaded assets as reproducible artifacts unless they are intentionally curated fixtures.
