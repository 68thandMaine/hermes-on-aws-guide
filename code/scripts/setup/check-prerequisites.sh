#!/usr/bin/env bash
# check-prerequisites.sh — Verify local tools required for the book are installed.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_command() {
    local cmd="$1"
    local name="${2:-$cmd}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -1 || "$cmd" version 2>&1 | head -1 || echo "installed")
        echo -e "${GREEN}✓${NC} $name: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $name: not found"
        return 1
    fi
}

echo "Checking prerequisites for Building a Personal AI Cloud..."
echo ""

MISSING=0

check_command git "Git" || MISSING=$((MISSING + 1))
check_command aws "AWS CLI" || MISSING=$((MISSING + 1))
check_command terraform "Terraform" || MISSING=$((MISSING + 1))
check_command docker "Docker" || MISSING=$((MISSING + 1))
check_command kubectl "kubectl" || MISSING=$((MISSING + 1))

echo ""

if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}All prerequisites met.${NC} Ready for Lab 1."
    exit 0
else
    echo -e "${YELLOW}$MISSING tool(s) missing.${NC} See Chapter 1, Lab 1 for installation instructions."
    exit 1
fi
