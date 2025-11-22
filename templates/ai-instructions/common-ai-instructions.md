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
- **docs/**: Astro Starlight documentation site using Diátaxis framework

## Documentation Standards

### Diátaxis Framework

All project documentation follows the [Diátaxis framework](https://diataxis.fr/) with four distinct content types:

- **Tutorials**: Learning-oriented lessons for beginners
  - Location: `docs/src/content/docs/tutorials/`
  - Purpose: Help users learn by doing
  - Format: Step-by-step instructions with expected outcomes

- **How-To Guides**: Task-oriented practical steps
  - Location: `docs/src/content/docs/guides/`
  - Purpose: Solve specific problems
  - Format: Goal-focused recipes and examples

- **Reference**: Information-oriented technical descriptions
  - Location: `docs/src/content/docs/reference/`
  - Purpose: Describe the machinery
  - Format: API docs, configuration options, specifications

- **Explanation**: Understanding-oriented discussions
  - Location: `docs/src/content/docs/explanation/`
  - Purpose: Clarify and illuminate topics
  - Format: Background, context, design decisions

### Astro Starlight

- **Framework**: [Astro Starlight](https://starlight.astro.build/) - Documentation site generator
- **Structure**: Markdown files in `docs/src/content/docs/`
- **Configuration**: `docs/astro.config.mjs` and `docs/src/starlight.config.ts`
- **Development**: `npm run dev` in docs/ directory
- **Build**: `npm run build` creates static site in `docs/dist/`

### Documentation Creation

When creating documentation:
1. **Identify content type** - Tutorial, Guide, Reference, or Explanation
2. **Place in correct directory** - Follow Diátaxis structure
3. **Use Starlight frontmatter**:
   ```markdown
   ---
   title: Page Title
   description: Brief description for SEO
   ---
   ```
4. **Include navigation** - Update sidebar in `astro.config.mjs` if needed
5. **Test locally** - Run dev server before committing
