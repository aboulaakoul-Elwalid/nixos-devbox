# User Profile: El Walid

## Identity
- Timezone: UTC+1 (Morocco)
- Focus: AI-assisted coding, autonomous agents, knowledge systems

## Working Style
- Track-based project organization (numbered tracks)
- Long planning sessions before implementation
- Autonomous away/night mode for heavy lifting
- CLI-first: build CLIs, then wrap with UI
- Git-tracked configs (version control everything)

## Preferences
- **Minimal** over feature-rich
- **Recommendation** over options
- **Concise** over verbose
- **Cheap models** over expensive by default
- **Subagents** over doing everything in main context when the task is non-trivial
- **Learning** always on when it helps understanding
- **Local-first compute** before cloud GPUs

## Communication Patterns
- Interrupts with new context frequently
- Pastes terminal output for analysis
- Says "do what best" when wants delegation
- Says "still don't work" when needs deeper investigation
- Dislikes excessive permission questions

## Tech Stack
- **OS**: NixOS
- **WM**: Hyprland + Omarchy-derived desktop layering
- **Terminal**: Ghostty (lowercase GTK app IDs required)
- **Shell**: Zsh + Zellij
- **Editor**: Neovim / VS Code
- **AI**: OpenCode with multi-provider auth

## Key Directories
- `~/.config/opencode/` - OpenCode config (Git-tracked)
- `~/.local/bin/` - Personal scripts
- `~/.local/share/omarchy/bin/` - Omarchy scripts
- `~/repos/` - Project repositories
- `~/Documents/vault_ai/` - Obsidian vault

## Don't Do
- Don't use Sisyphus agent naming
- Don't suggest macOS-specific solutions
- Don't create heavy configs when minimal works
- Don't burn Opus quota on simple tasks
- Don't ask "which option do you prefer" - just recommend
- Don't repeat the same fix when "still don't work"

## Auth Sources
- Google Antigravity (Pro subscription, 3 accounts for 3x rate limits)
- OpenAI Codex (ChatGPT Pro)
- GitHub Copilot Pro (unlimited GPT-5 mini)

## CLI Install Sources
- `opencode` is npm-managed at `~/.npm-global/bin/opencode`, wrapped by `~/.local/bin/opencode`
- `codex` is npm-managed at `~/.npm-global/bin/codex`
- NixOS provides system dependencies and wrappers, not the fast-moving CLI releases

## Current Model Preferences (2026-07-10)
- **Default general subagent**: GPT 5.6 Terra (`openai/gpt-5.6-terra`)
- **Deep implementation worker**: GPT 5.6 Terra Pro (`openai/gpt-5.6-terra-pro`)
- **GPT oracle / proof-style reasoning**: GPT 5.6 Sol (`openai/gpt-5.6-sol`)
- **Planning and deep review**: GPT 5.6 Sol (`openai/gpt-5.6-sol`)
- **Fallback GPT oracle**: GPT 5.4 xhigh (`openai/gpt-5.4`)
- **Codex deep work**: GPT 5.3 Codex high (`openai/gpt-5.3-codex-high`) - PAID
- **Opus lane**: GitHub Copilot Opus for oracle use
- **Grok oracle**: xAI Grok 4.5 (`xai/grok-4.5`) via OpenCode `oracle-grok` / council `consult-grok.sh`
- **Explore/docs lane**: GPT-5 mini via Copilot (`github-copilot/gpt-5-mini`)
