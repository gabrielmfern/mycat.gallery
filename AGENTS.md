# AGENTS.md - Development Guidelines

## Build/Test Commands
- `zig build` - Build the project
- `zig build run` - Build and run the application
- `zig build test` - Run all unit tests
- No specific single test command available (use `zig build test` for all tests)

## Project Structure
- Zig web server project with HTTP routing
- Entry point: `src/main.zig`
- Routes defined in `src/routes/` directory
- Helper utilities in `src/helper.zig`

## Code Style Guidelines
- Use snake_case for variables and functions
- Use PascalCase for types and structs
- Import std library as `std`
- Use explicit error handling with `try` and `anyerror!void`
- Defer cleanup operations (e.g., `defer server.deinit()`)
- Use `std.log` for logging with appropriate levels (info, debug, warn)
- Memory management: use GeneralPurposeAllocator, check for leaks on deinit

## Naming Conventions
- Route handlers: `handler` function with `method` and `pathname` constants
- Global allocator: `allocator` variable in main.zig
- HTTP-related imports: use `http` alias for `std.http`

## Error Handling
- Use `anyerror!void` for functions that can fail
- Propagate errors with `try`
- Log warnings for memory leaks and other issues