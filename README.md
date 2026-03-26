# ai-agent-skills

Sassy Dog AI agent skills marketplace for Claude Code, Gemini CLI, and other AI coding tools.

## Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `ai-agent-skills` | `github-secrets` | GitHub Actions secrets & variables — scope hierarchy, CLI usage, common mistakes |

## Installation

### Claude Code

```bash
# Add as a marketplace
claude plugin marketplace add Sassy-Dog/ai-agent-skills

# Install the plugin
claude plugin install ai-agent-skills
```

### Local Development

```bash
claude --plugin-dir ~/Repos/sassy-dog/ai-agent-skills/plugins/ai-agent-skills
```

## Adding Skills

Skills live inside plugins under `plugins/<plugin-name>/skills/`:

```
plugins/ai-agent-skills/
├── .claude-plugin/plugin.json
└── skills/
    └── my-skill/
        ├── SKILL.md           # Required — frontmatter + instructions
        └── references/        # Optional — detailed reference docs
```
