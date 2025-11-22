#!/usr/bin/env bash
#
# VS Code Workspace Bootstrap Script (Linux/macOS)
#
# Idempotent workspace initialization for consistent dev environments.
# Automatically creates:
#   - .vscode structure (settings.json with absolute interpreter path, tasks.json)
#   - .ai directory with AI instruction files (common, gemini, copilot)
#   - Python virtual environment (.venv)
#   - Installs base dev packages (pytest, flake8)
#   - Handles torch + torchvision with CU130 index
#   - Clones spec-kit repo and optionally launches copilot CLI
#
# Author: hellosamblack
# Version: 1.0.0
# Repository: https://github.com/hellosamblack/bootstrap
#
# Usage:
#   Run via user-level folderOpen task or manually:
#     bash create_workspace_scaffold.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------
scaffold_info() {
    echo -e "\033[0;36m[workspace-scaffold]\033[0m $1"
}

scaffold_error() {
    echo -e "\033[0;31m[workspace-scaffold] ERROR:\033[0m $1" >&2
}

ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

ensure_file() {
    local path="$1"
    local content="$2"
    if [ ! -f "$path" ]; then
        echo "$content" > "$path"
    fi
}

# ---------------------------------------------------------------------------
# Main Bootstrap Logic
# ---------------------------------------------------------------------------
workspace_root="$(pwd)"
scaffold_info "Bootstrapping workspace at '$workspace_root'"

# ---------------------------------------------------------------------------
# 1. VSCode .vscode structure
# ---------------------------------------------------------------------------
vscode_dir="$workspace_root/.vscode"
tasks_file="$vscode_dir/tasks.json"
settings_file="$vscode_dir/settings.json"
ensure_dir "$vscode_dir"

if [ ! -f "$tasks_file" ]; then
    scaffold_info "Creating workspace tasks.json"
    cat > "$tasks_file" <<'TASKS_EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Create workspace venv (Windows)",
      "type": "shell",
      "command": "if (-not (Test-Path .venv\\Scripts\\python.exe)) { py -3 -m venv .venv }",
      "presentation": {
        "echo": false,
        "reveal": "never",
        "focus": false,
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": [],
      "windows": {
        "command": "if (-not (Test-Path .venv\\Scripts\\python.exe)) { py -3 -m venv .venv }"
      }
    },
    {
      "label": "Create workspace venv (Linux/Mac)",
      "type": "shell",
      "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi",
      "presentation": {
        "echo": false,
        "reveal": "never",
        "focus": false,
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": [],
      "linux": {
        "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
      },
      "osx": {
        "command": "if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi"
      }
    }
  ]
}
TASKS_EOF
fi

# ---------------------------------------------------------------------------
# 2. settings.json with absolute interpreter path
# ---------------------------------------------------------------------------
if [ ! -f "$settings_file" ]; then
    scaffold_info "Creating settings.json with absolute interpreter path"
    interpreter_absolute="$workspace_root/.venv/bin/python"
    
    cat > "$settings_file" <<SETTINGS_EOF
{
  "python.defaultInterpreterPath": "$interpreter_absolute",
  "python.terminal.activateEnvInCurrentTerminal": true,
  "python.terminal.useEnvFile": true,
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.linting.flake8Args": [
    "--max-line-length=120"
  ],
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false
}
SETTINGS_EOF
fi

# ---------------------------------------------------------------------------
# 3. AI instruction files (.ai directory)
# ---------------------------------------------------------------------------
ai_dir="$workspace_root/.ai"
ensure_dir "$ai_dir"

# Download AI instruction templates from bootstrap repo
template_base_url="https://raw.githubusercontent.com/hellosamblack/bootstrap/main/templates/ai-instructions"
declare -A ai_templates=(
    ["common-ai-instructions.md"]="$ai_dir/common-ai-instructions.md"
    ["gemini.instructions.md"]="$ai_dir/gemini.instructions.md"
    ["copilot.instructions.md"]="$ai_dir/copilot.instructions.md"
)

for template in "${!ai_templates[@]}"; do
    local_path="${ai_templates[$template]}"
    if [ ! -f "$local_path" ]; then
        scaffold_info "Downloading AI instruction template: $template"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$template_base_url/$template" -o "$local_path" || scaffold_error "Could not download $template (will use defaults)"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$template_base_url/$template" -O "$local_path" || scaffold_error "Could not download $template (will use defaults)"
        else
            scaffold_error "Neither curl nor wget available; cannot download templates"
        fi
    fi
done

# ---------------------------------------------------------------------------
# 3b. GitHub Agents directory (.github/agents/)
# ---------------------------------------------------------------------------
github_dir="$workspace_root/.github"
agents_dir="$github_dir/agents"
ensure_dir "$github_dir"
ensure_dir "$agents_dir"

# Detect project type and create appropriate agent files
project_type="general"
if [ -d "$workspace_root/ignition" ]; then
    project_type="ignition"
elif [ -d "$workspace_root/models" ] || [ -f "$workspace_root/scripts/train.py" ]; then
    project_type="llm"
elif [ -d "$workspace_root/homeassistant" ] || [ -f "$workspace_root/configuration.yaml" ]; then
    project_type="homeassistant"
fi

scaffold_info "Detected project type: $project_type"

# Download agent templates from bootstrap repo
agent_base_url="https://raw.githubusercontent.com/hellosamblack/bootstrap/main/.github/agents"
declare -A agent_files=(
    ["ignition"]="ignition-agent.md"
    ["llm"]="llm-agent.md"
    ["homeassistant"]="homeassistant-agent.md"
)

if [[ -n "${agent_files[$project_type]:-}" ]]; then
    agent_file="$agents_dir/${agent_files[$project_type]}"
    if [ ! -f "$agent_file" ]; then
        scaffold_info "Downloading ${agent_files[$project_type]} agent template"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$agent_base_url/${agent_files[$project_type]}" -o "$agent_file" || scaffold_info "Could not download agent template (will be available after repo sync)"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$agent_base_url/${agent_files[$project_type]}" -O "$agent_file" || scaffold_info "Could not download agent template (will be available after repo sync)"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Python dependency bootstrap with torch handling
# ---------------------------------------------------------------------------
venv_python="$workspace_root/.venv/bin/python"
bootstrap_sentinel="$workspace_root/.venv/.bootstrap_done"
requirements_path="$workspace_root/requirements.txt"

if [ -x "$venv_python" ] && [ ! -f "$bootstrap_sentinel" ]; then
    scaffold_info "Bootstrapping Python dependencies"
    
    "$venv_python" -m pip install --upgrade pip >/dev/null 2>&1 || true
    scaffold_info "Installing base dev packages (pytest, flake8)"
    "$venv_python" -m pip install pytest flake8 >/dev/null 2>&1 || true
    
    if [ -f "$requirements_path" ]; then
        torch_present=$(grep -E '^\s*torch(\b|[=<>])' "$requirements_path" || true)
        torchvision_present=$(grep -E '^\s*torchvision(\b|[=<>])' "$requirements_path" || true)
        
        if [ -n "$torch_present" ] && [ -z "$torchvision_present" ]; then
            scaffold_info "Adding torchvision to requirements.txt"
            echo "torchvision" >> "$requirements_path"
        fi
        
        if [ -n "$torch_present" ]; then
            scaffold_info "Installing torch + torchvision (CU130 index)"
            "$venv_python" -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130 || true
        fi
        
        # Install remaining requirements (excluding torch/torchvision, comments, blank lines)
        temp_req=$(mktemp)
        grep -Ev '^\s*(torch|torchvision)(\b|[=<>])|^\s*#|^\s*$' "$requirements_path" > "$temp_req" || true
        if [ -s "$temp_req" ]; then
            scaffold_info "Installing remaining requirements"
            "$venv_python" -m pip install -r "$temp_req" || true
        fi
        rm -f "$temp_req"
    fi
    
    touch "$bootstrap_sentinel"
    scaffold_info "Dependency bootstrap complete"
fi

# ---------------------------------------------------------------------------
# 5. Astro Starlight documentation site
# ---------------------------------------------------------------------------
docs_dir="$workspace_root/docs"
if [ ! -d "$docs_dir" ]; then
    if command -v npm >/dev/null 2>&1; then
        scaffold_info "Creating Astro Starlight documentation site"
        (
            cd "$workspace_root" || exit 1
            npm create astro@latest docs -- --template starlight --install --no-git --typescript strict || scaffold_error "Failed to create documentation site"
            
            # Create Diátaxis directory structure
            content_dir="$docs_dir/src/content/docs"
            mkdir -p "$content_dir/tutorials"
            mkdir -p "$content_dir/guides"
            mkdir -p "$content_dir/reference"
            mkdir -p "$content_dir/explanation"
            
            scaffold_info "Documentation site created with Diátaxis structure"
        )
    else
        scaffold_info "npm not found; skipping documentation site creation"
    fi
fi

# ---------------------------------------------------------------------------
# 6. spec-kit repository clone & copilot CLI launch
# ---------------------------------------------------------------------------
repo_dir="$workspace_root/spec-kit"
if [ ! -d "$repo_dir" ]; then
    if command -v gh >/dev/null 2>&1; then
        scaffold_info "Cloning spec-kit repository"
        gh repo clone github/spec-kit "$repo_dir" || scaffold_error "Failed to clone spec-kit"
    elif command -v git >/dev/null 2>&1; then
        scaffold_info "Cloning spec-kit repository (via git)"
        git clone https://github.com/github/spec-kit.git "$repo_dir" || scaffold_error "Failed to clone spec-kit"
    else
        scaffold_info "Neither gh nor git CLI found; skipping spec-kit clone"
    fi
fi

if [ -d "$repo_dir" ] && command -v copilot >/dev/null 2>&1; then
    scaffold_info "Launching copilot CLI in spec-kit"
    (cd "$repo_dir" && copilot) || scaffold_error "copilot CLI launch failed"
elif ! command -v copilot >/dev/null 2>&1; then
    scaffold_info "copilot CLI not available; skipping launch"
fi

scaffold_info "Workspace scaffold complete!"
