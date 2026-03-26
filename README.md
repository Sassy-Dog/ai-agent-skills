# ai-agent-skills

Reusable AI agent skills for Claude Code, Gemini CLI, and other AI coding tools.

## Skills

| Skill | Description |
|-------|-------------|
| `github-secrets` | GitHub Actions secrets & variables — scope hierarchy, CLI usage, common mistakes |

## Installation

### Claude Code

```bash
claude plugin add sassy-dog/ai-agent-skills
```

Or for local development:

```bash
claude --plugin-dir ~/Repos/sassy-dog/ai-agent-skills
```

## Adding Skills

Create a new directory under `skills/` with a `SKILL.md` file:

```
skills/
└── my-skill/
    ├── SKILL.md           # Required — frontmatter + instructions
    └── references/        # Optional — detailed reference docs
```
