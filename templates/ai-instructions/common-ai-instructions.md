# Common AI Instructions

## Development Standards

### Python Environment

- **Virtual Environment**: Always use workspace `.venv` for Python tooling
- **Interpreter**: Absolute path configured in workspace settings
- **Global Installs**: Disabled to ensure isolation

### Code Style & Quality

- **Max Line Length**: 120 characters
- **Linter**: flake8 only (no Black formatter by default)
- **Tests**: pytest only (unittest disabled)
- **Type Hints**: Encouraged where beneficial

### Dependencies

- **Latest Versions**: Install unpinned packages at latest stable versions
- **PyTorch**: Always install `torch` + `torchvision` together via CU130 index:

  ```bash
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
  ```

### Security

- **Secrets Management**: Use environment variables via 1Password CLI
- **No Hardcoded Credentials**: All sensitive data via `${env:VAR_NAME}`
- **SSH Keys**: Use privateKeyPath with env vars for passwords

### Communication Style

- **Concise**: Provide direct answers unless verbosity requested
- **Actionable**: Focus on practical implementation
- **Context-Aware**: Reference workspace structure and existing patterns

## AI Toolkit Commands

When working with AI/Agent development, leverage these tools:

- `aitk-get_agent_code_gen_best_practices` - Best practices for AI agent development
- `aitk-get_tracing_code_gen_best_practices` - Tracing implementation guidance
- `aitk-get_ai_model_guidance` - AI model selection and usage
- `aitk-evaluation_planner` - Evaluation metrics clarification (multi-turn)
- `aitk-get_evaluation_code_gen_best_practices` - Evaluation code generation
- `aitk-evaluation_agent_runner_best_practices` - Agent runner best practices

## Repository Standards

### Workspace Bootstrap

- This workspace was initialized via [bootstrap](https://github.com/hellosamblack/bootstrap)
- Scaffold script creates consistent structure across machines
- Settings Sync propagates user-level tasks automatically

### Default Actions

- **spec-kit**: Automatically cloned to workspace root
- **copilot CLI**: Launched in spec-kit directory if available
- **Dev Packages**: pytest, flake8 installed automatically on first bootstrap
