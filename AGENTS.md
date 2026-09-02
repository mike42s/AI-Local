# AI-Local

## Project Structure

- frontend/ = Flutter application
- backend/ = Node.js Express API
- ai/ = local AI related configuration

## General Rules

- Do not delete files unless explicitly requested.
- Do not modify files outside this project.
- Do not expose secrets or credentials.
- Never commit .env files.
- Make small incremental changes.
- Explain major architectural changes before implementing them.
- Run tests or validation after significant changes.
- Keep frontend and backend responsibilities separated.

## Flutter

- Use Dart null safety.
- Follow Flutter best practices.
- Keep UI, state management, models, services, and API logic organized.
- Run flutter analyze after significant changes.
- Run relevant Flutter tests after significant changes.

## Backend

- Use Node.js with Express.
- Use environment variables for configuration.
- Keep API routes organized.
- Validate API input.
- Never hardcode passwords, API keys, or database credentials.

## AI Behavior

- Inspect the existing project before modifying it.
- Prefer minimal changes.
- Do not rewrite working code unnecessarily.
- When encountering an error, investigate the root cause before changing unrelated code.
- After changes, verify the affected functionality.
