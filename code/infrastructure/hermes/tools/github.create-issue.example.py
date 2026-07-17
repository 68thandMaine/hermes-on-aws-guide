#!/usr/bin/env python3
"""
Chapter 42 — Illustrative GitHub tool implementation (worker-side only).

The model proposes JSON matching github.create-issue.schema.json.
The worker validates, authorizes (Ch 41), then calls this handler.
Credentials come from GITHUB_TOKEN env (ESO → Pod), never from the prompt.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def create_issue(params: dict) -> dict:
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        raise RuntimeError("GITHUB_TOKEN not configured (check ExternalSecret)")

    owner = params["owner"]
    repo = params["repository"]
    url = f"https://api.github.com/repos/{owner}/{repo}/issues"

    body = {
        "title": params["title"],
        "body": params.get("body", ""),
        "labels": params.get("labels", []),
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "hermes-worker",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            result = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        err_body = e.read().decode() if e.fp else ""
        raise RuntimeError(f"GitHub API {e.code}: {err_body}") from e

    # Normalized response for reasoning loop — stable shape regardless of API version
    return {
        "issue_number": result["number"],
        "html_url": result["html_url"],
        "state": result["state"],
    }


if __name__ == "__main__":
    # Lab: echo '{"owner":"org","repository":"hermes","title":"Test"}' | python3 ...
    params = json.load(sys.stdin)
    print(json.dumps(create_issue(params), indent=2))
