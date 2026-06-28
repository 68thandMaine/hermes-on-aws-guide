# Scripts

Helper scripts used across book chapters. Scripts are referenced from lab instructions and should be idempotent where possible.

## Directory Structure

```
scripts/
├── README.md              # This file
├── setup/                 # One-time environment setup
│   └── check-prerequisites.sh
├── ci/                    # CI scripts run in GitHub Actions
│   └── validate-links.sh
└── terraform/             # Starter Terraform configs (Ch 28)
    └── README.md
```

## Available Scripts

| Script | Purpose | Chapter |
|--------|---------|---------|
| `setup/check-prerequisites.sh` | Verify local tools are installed | 1 |
| `ci/validate-links.sh` | Validate internal Markdown links (CI) | — |

## Conventions

- All scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Scripts accept `--help` for usage information
- Scripts print what they are doing before doing it
- Destructive operations require explicit confirmation or a `--force` flag
- Never embed secrets in scripts — use environment variables or AWS profiles

## Running Scripts

```bash
chmod +x scripts/setup/check-prerequisites.sh
./scripts/setup/check-prerequisites.sh
```

## Adding Scripts

When a lab requires repeated or complex commands, extract them into a script here. Reference the script from the chapter lab section with its path and usage.
