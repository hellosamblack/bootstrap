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

## PowerShell Development

### Script Standards

- **PowerShell Version**: Target PowerShell 7.x (cross-platform)
- **Compatibility**: Include PowerShell 5.x compatibility where needed
- **Error Handling**: Always use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
- **Encoding**: UTF-8 with BOM for cross-platform compatibility

### Common Pitfalls & Solutions

**1. Array/Collection .Count Property Errors**

Problem: `The property 'Count' cannot be found on this object`

- Occurs when pipeline returns `$null`, single object, or certain collection types
- `.Count` property doesn't exist on all return types

✅ **Solution**: Always wrap variables in `@()` before accessing `.Count`:

```powershell
# ❌ WRONG - will fail if $result is null or single object
if ($result.Count -gt 0) { ... }

# ✅ CORRECT - forces array type
if (@($result).Count -gt 0) { ... }
```

**2. Python Launcher Missing**

Problem: `py: The term 'py' is not recognized`

- Windows Python installations vary (py launcher, python3, python)
- Can't assume any specific command is available

✅ **Solution**: Use fallback chain with try/catch:

```powershell
# ❌ WRONG - assumes py launcher exists
py -3 -m venv .venv

# ✅ CORRECT - tries multiple commands
try { 
    py -3 -m venv .venv 
} catch { 
    try { 
        python3 -m venv .venv 
    } catch { 
        try { 
            python -m venv .venv 
        } catch { 
            Write-Error "Python not found; install from python.org"
            exit 1
        }
    }
}
```

**3. Here-String Indentation**

Problem: `White space is not allowed before the string terminator`

- Here-string terminators (`'@` or `"@`) must be at column 0
- No leading whitespace allowed before closing marker

✅ **Solution**: Never indent here-string terminators:

```powershell
# ❌ WRONG - terminator is indented
function Get-Json {
    $json = @'
    {
        "key": "value"
    }
    '@
}

# ✅ CORRECT - terminator at column 0
function Get-Json {
    $json = @'
{
    "key": "value"
}
'@
}
```

**4. Variable Interpolation in Strings**

Problem: `$variable: $_` fails to parse

- Colon after variable name requires braces for disambiguation
- PowerShell can't determine where variable name ends

✅ **Solution**: Use `${variable}` when followed by special characters:

```powershell
# ❌ WRONG - parser can't determine variable boundary
"$template: $_"

# ✅ CORRECT - explicit variable boundary
"${template}: $_"
```

**5. Nested Shell Invocation**

Problem: `ScriptBlock should only be specified as a value of the Command parameter`

- Nested `powershell -Command "..."` creates parsing issues
- Escaping becomes complex and error-prone

✅ **Solution**: Use direct command + args array:

```powershell
# ❌ WRONG - nested shell with escaped quotes
"command": "powershell -Command \"if (Test-Path file) { ... }\""

# ✅ CORRECT - direct execution with args
"command": "pwsh",
"args": ["-NoProfile", "-Command", "if (Test-Path file) { ... }"]
```

### Cross-Platform Compatibility

**Detect OS correctly:**

```powershell
# PowerShell 5.x doesn't have $IsWindows/$IsLinux/$IsMacOS
if (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) { 
    $IsWindows = ($env:OS -eq 'Windows_NT') 
}
if (-not (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue)) { 
    $IsLinux = (-not $IsWindows) -and (Test-Path '/etc/os-release') 
}
if (-not (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue)) { 
    try { $uname = (uname) 2>$null } catch { $uname = '' }
    $IsMacOS = (-not $IsWindows) -and (-not $IsLinux) -and ($uname -eq 'Darwin') 
}
```

**Use platform-appropriate paths:**

```powershell
# Windows
$venvPython = Join-Path $workspaceRoot '.venv\Scripts\python.exe'

# Linux/Mac
$venvPython = Join-Path $workspaceRoot '.venv/bin/python'

# Combined
if ($IsWindows) { 
    $venvPython = Join-Path $workspaceRoot '.venv\Scripts\python.exe' 
} else { 
    $venvPython = Join-Path $workspaceRoot '.venv/bin/python' 
}
```

### Testing PowerShell Scripts

Always test with:
- `pwsh -NoProfile -File script.ps1` - Ensures clean environment
- `-WhatIf` parameter for destructive operations
- `Set-StrictMode -Version Latest` catches common errors
- Both PowerShell 5.1 and 7.x where cross-version support needed

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
