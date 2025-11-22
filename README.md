# VS Code Workspace Bootstrap

Automated workspace initialization system for consistent development environments across machines using VS Code Settings Sync.

## 🎯 Purpose

This repository provides a PowerShell script that automatically configures new workspaces with:
- ✅ Python virtual environment (`.venv`)
- ✅ VS Code settings with absolute interpreter paths
- ✅ AI instruction files (Gemini & Copilot)
- ✅ Dev tooling (pytest, flake8)
- ✅ PyTorch with torchvision (CU130 index)
- ✅ spec-kit repository clone
- ✅ Consistent code standards (120 line length, flake8 linting)

## 🚀 Quick Start

### 1. Add User-Level Task (Syncs Across Machines)

Add this task to your VS Code `tasks.json` (User level: `File > Preferences > User Tasks` or `%APPDATA%\Code\User\tasks.json`):

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Update & Run Workspace Bootstrap",
      "type": "shell",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"$scriptPath = Join-Path $env:APPDATA 'Code\\User\\create_workspace_scaffold.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/create_workspace_scaffold.ps1' -OutFile $scriptPath; & $scriptPath\"",
      "presentation": {
        "echo": false,
        "reveal": "silent",
        "focus": false,
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": []
    }
  ]
}
```

**For VS Code Insiders**, replace `Code\\User\\` with `Code - Insiders\\User\\`.

### 2. Enable Settings Sync

1. Open VS Code Settings Sync: `Ctrl+Shift+P` → `Settings Sync: Turn On`
2. Sign in with GitHub/Microsoft account
3. Ensure **Settings** and **Tasks** are enabled in sync preferences

### 3. Done!

Every time you open a workspace folder:
1. Script auto-updates from this repository
2. Workspace structure is initialized if missing
3. Python environment and dependencies are configured

## 📁 What Gets Created

### Workspace Structure
```
your-workspace/
├── .vscode/
│   ├── settings.json       # Absolute interpreter path, linting config
│   └── tasks.json          # Venv creation tasks (idempotent)
├── .venv/                  # Python virtual environment
│   ├── Scripts/            # (Windows) or bin/ (Linux/Mac)
│   └── .bootstrap_done     # Sentinel to prevent re-bootstrapping
├── .ai/
│   ├── common-ai-instructions.md    # Shared standards
│   ├── gemini.instructions.md       # Google Gemini specific
│   └── copilot.instructions.md      # GitHub Copilot specific
├── spec-kit/               # Cloned github/spec-kit repository
└── requirements.txt        # (if exists) Installed with torch handling
```

### Generated `settings.json`
```json
{
  "python.defaultInterpreterPath": "C:\\full\\path\\to\\.venv\\Scripts\\python.exe",
  "python.terminal.activateEnvInCurrentTerminal": true,
  "python.terminal.useEnvFile": true,
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.linting.flake8Args": ["--max-line-length=120"],
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false
}
```

## 🔧 Configuration Standards

### Python Environment
- **Interpreter**: Workspace-local `.venv` with absolute path
- **Linter**: flake8 (120 char line length)
- **Formatter**: None by default (manual choice)
- **Testing**: pytest only
- **Dev Packages**: pytest, flake8 auto-installed

### PyTorch Special Handling
If `requirements.txt` contains `torch`:
- Automatically adds `torchvision` if missing
- Installs both via CU130 index:
  ```bash
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
  ```
- Other requirements installed separately to avoid conflicts

### Security
- **1Password CLI Integration**: Use `${env:OP_VAR_NAME}` in settings
- **SSH Keys**: Store keys locally, reference via `privateKeyPath`
- **No Hardcoded Secrets**: All credentials via environment variables

## 📋 Manual Usage

Run the script manually in any workspace:

```powershell
# Download & execute once
Invoke-WebRequest -UseBasicParsing `
  -Uri 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/create_workspace_scaffold.ps1' `
  -OutFile create_workspace_scaffold.ps1

pwsh -NoProfile -ExecutionPolicy Bypass -File create_workspace_scaffold.ps1
```

## 🛠️ Customization

### Modify User Settings (Synced Globally)
Edit `%APPDATA%\Code\User\settings.json` for:
- Global Python settings
- Editor preferences
- Extension configurations
- SSHFS configurations
- Files exclusions

### Workspace-Specific Overrides
Edit `.vscode/settings.json` in any workspace to override global defaults.

### Custom Dependency Handling
Add logic to `create_workspace_scaffold.ps1` around line 250 for special package handling similar to the torch example.

## 🔄 Update Strategy

**Automatic** (Recommended):
- Task fetches latest script from GitHub on every folder open
- Changes propagate immediately after repo push
- No manual intervention needed

**Manual**:
```powershell
# Re-download script to user directory
Invoke-WebRequest -UseBasicParsing `
  -Uri 'https://raw.githubusercontent.com/hellosamblack/bootstrap/main/create_workspace_scaffold.ps1' `
  -OutFile "$env:APPDATA\Code\User\create_workspace_scaffold.ps1"
```

## 🌐 Cross-Platform Notes

### Windows
- Uses `py -3` launcher
- Paths: `.venv\Scripts\python.exe`
- Default shell: PowerShell

### Linux/macOS
- Uses `python3` command
- Paths: `.venv/bin/python`
- Default shell: bash

Script automatically detects platform and adjusts paths/commands.

## 🐛 Troubleshooting

### Script Doesn't Run on Folder Open
1. Check task is present: `Terminal > Run Task > Update & Run Workspace Bootstrap`
2. Verify `runOptions.runOn` is set to `"folderOpen"`
3. Reload VS Code window: `Ctrl+Shift+P` → `Developer: Reload Window`

### Venv Creation Fails
```powershell
# Test Python availability
py -3 --version        # Windows
python3 --version      # Linux/Mac

# Manually create venv
py -3 -m venv .venv    # Windows
python3 -m venv .venv  # Linux/Mac
```

### Interpreter Not Detected
1. Delete `.vscode/settings.json`
2. Reopen workspace folder (triggers regeneration)
3. Select interpreter: `Ctrl+Shift+P` → `Python: Select Interpreter`

### Dependencies Won't Install
```powershell
# Check venv activation
.\.venv\Scripts\Activate.ps1    # Windows
source .venv/bin/activate       # Linux/Mac

# Manually install
pip install --upgrade pip
pip install pytest flake8
pip install -r requirements.txt
```

### Script Updates Not Applying
Clear cached script:
```powershell
Remove-Item "$env:APPDATA\Code\User\create_workspace_scaffold.ps1"
```
Reopen workspace to re-download.

## 📚 AI Instructions & Agents

### AI Instruction Files (`.ai/` directory)

Standardized instructions for AI assistants across all projects:

- **`common-ai-instructions.md`**: Base standards (style, security, tooling)
- **`gemini.instructions.md`**: Google Gemini-specific guidance
- **`copilot.instructions.md`**: GitHub Copilot-specific guidance

Both model-specific files reference the common instructions to maintain consistency.

### GitHub Copilot Agents (`.github/agents/` directory)

**NEW**: Specialized AI agents with full execution permissions for project-specific tasks. The bootstrap script automatically detects your project type and downloads the appropriate agent configuration.

#### Available Agents

**1. @ignition_agent** (`ignition-agent.md`)
- **Expertise**: Ignition SCADA development
- **Skills**: JSON configs, SQL queries, Ignition expressions, Python/Jython scripting
- **Autonomy**: Full execution - creates Perspective views, modifies tags, writes SQL
- **Detects**: Projects with `ignition/` directory
- **Use cases**: Building HMI screens, writing named queries, tag configuration, gateway scripts

**2. @llm_agent** (`llm-agent.md`)
- **Expertise**: Local LLM development and deployment
- **Skills**: PyTorch, Transformers, LoRA/QLoRA fine-tuning, GGUF quantization, inference optimization
- **Autonomy**: Full execution - installs packages, downloads models, runs training, converts/quantizes
- **Detects**: Projects with `models/` directory or `scripts/train.py`
- **Use cases**: Fine-tuning models, converting to GGUF, quantization, benchmarking, dataset preparation

**3. @homeassistant_agent** (`homeassistant-agent.md`)
- **Expertise**: Home Assistant & ESPHome development
- **Skills**: YAML configs, automations, Lovelace dashboards, ESPHome firmware, MQTT
- **Autonomy**: Full execution - modifies configs, flashes ESP devices, creates automations
- **Detects**: Projects with `homeassistant/` directory or `configuration.yaml`
- **Use cases**: Building automations, configuring integrations, ESPHome devices, dashboards

#### Using Agents

**In GitHub Copilot Chat:**
```
@ignition_agent create a perspective view for tank level monitoring with alarm indicators

@llm_agent fine-tune Llama-2-7b on my instruction dataset and convert to Q4_K_M GGUF

@homeassistant_agent create an automation that turns on lights when motion is detected after sunset
```

**Agent Autonomy:**
- ✅ **Full execution permissions** - Agents can make changes, create files, run commands without asking
- ✅ **Project-aware** - Understand your tech stack, file structure, and coding standards
- ✅ **Best practices built-in** - Follow security, performance, and maintainability guidelines
- ⚠️ **Smart boundaries** - Know what requires confirmation (production deploys, schema changes)

**Agent Features:**
- Executable commands with exact syntax
- Real code examples (not abstract descriptions)
- Clear boundaries (always/ask first/never)
- Project-specific context and standards
- Testing and validation steps

#### Customizing Agents

Edit `.github/agents/*.md` files to:
- Add project-specific commands
- Update tech stack versions
- Define custom code standards
- Set additional boundaries
- Add examples from your codebase

Agents are version-controlled and sync across machines via git.

## 🤝 Contributing

1. Fork this repository
2. Modify `create_workspace_scaffold.ps1`
3. Test across Windows/Linux/macOS if possible
4. Submit PR with description of changes

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🔗 Related

- [VS Code Settings Sync](https://code.visualstudio.com/docs/editor/settings-sync)
- [Python Virtual Environments](https://docs.python.org/3/library/venv.html)
- [GitHub CLI](https://cli.github.com/)
- [1Password CLI](https://developer.1password.com/docs/cli)
- [spec-kit Repository](https://github.com/github/spec-kit)

---

**Repository**: [hellosamblack/bootstrap](https://github.com/hellosamblack/bootstrap)  
**Author**: hellosamblack  
**Version**: 1.0.0