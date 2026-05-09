#!/bin/bash
set -e

SKILLS_DIR="${HOME}/.claude/skills"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS=(client-auditor contract-auditor exploit-investigator)

mkdir -p "${SKILLS_DIR}"

for skill in "${SKILLS[@]}"; do
  rsync -a --delete --exclude '.DS_Store' "${REPO_DIR}/${skill}/" "${SKILLS_DIR}/${skill}/"
  echo "synced: ${skill}"
done

echo "All skills installed to ${SKILLS_DIR}"
