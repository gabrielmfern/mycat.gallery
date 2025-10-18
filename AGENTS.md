# AGENTS.md - Development Guidelines

## Build/Test Commands
- `zig build` - Build the project
- `zig build run` - Build and run the application (includes route generation)
- `zig build test` - Run all unit tests (webserver + glue tests)
- `./dev.sh` - Development mode with file watching (uses watchexec)
- No specific single test command available (use `zig build test` for all tests)

## Project Structure
- Zig web server project with HTTP routing using file-based routing
- Entry point: `src/main.zig`
- Routes auto-generated from `src/app/` directory structure to `src/routes.zig`
- Components in `src/components/` (layout.zig, logo.zig)
- Database layer in `src/database.zig`
- Dependencies: sqlite, uuid via build.zig.zon

## Code Style Guidelines
- Use snake_case for variables and functions
- Use PascalCase for types and structs
- Import std library as `std`, http as `std.http`
- Use explicit error handling with `try` and `anyerror!void`
- Defer cleanup operations (e.g., `defer server.deinit()`, `defer arena.deinit()`)
- Use ArenaAllocator per request, GeneralPurposeAllocator for main thread
- Use `std.log` for logging with appropriate levels (info, debug, warn)
- Memory management: check for leaks on deinit with `.leak` detection

## Naming Conventions
- Route handlers: `handler` function (no method/pathname constants needed)
- Thread-local functions: `use_allocator()`, `use_database()`
- HTTP-related imports: use `http` alias for `std.http`

## Error Handling
- Use `anyerror!void` for functions that can fail
- Propagate errors with `try`
- Log warnings for memory leaks and other issues