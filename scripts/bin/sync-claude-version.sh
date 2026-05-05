#!/bin/bash
# sync-claude-version.sh
#
# 호스트(WSL2 native)의 Claude Code 버전을 컨테이너 이미지 핀에 반영한다.
# 호스트 = "버전 진실의 원천", 컨테이너 = 그걸 추종하는 immutable 빌드.
#
# 사용:
#   make sync         # 호스트 버전 → .env 갱신 + 이미지 재빌드
#   make sync && make restart  # 재빌드 후 컨테이너 교체
#
# 동작:
#   1) `claude --version` 으로 호스트 버전 추출
#   2) .env 의 CLAUDE_CODE_VERSION 과 비교
#   3) 다르면 .env 갱신 + `docker compose build claude`
#   4) 같으면 no-op

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: 'claude' not found in PATH on host." >&2
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: ${ENV_FILE} not found. Copy .env.example first." >&2
    exit 1
fi

HOST_VER=$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "${HOST_VER:-}" ]; then
    echo "ERROR: failed to parse host claude version." >&2
    exit 1
fi

CURRENT=$(grep '^CLAUDE_CODE_VERSION=' "$ENV_FILE" | cut -d= -f2 || true)

echo "Host Claude Code: ${HOST_VER}"
echo "Container pin:    ${CURRENT:-(unset)}"

if [ "$HOST_VER" = "$CURRENT" ]; then
    echo "Already in sync. No rebuild needed."
    exit 0
fi

echo
echo "Updating ${ENV_FILE}: ${CURRENT:-(unset)} -> ${HOST_VER}"
sed -i "s/^CLAUDE_CODE_VERSION=.*/CLAUDE_CODE_VERSION=${HOST_VER}/" "$ENV_FILE"

echo
echo "Rebuilding image..."
cd "$REPO_ROOT"
docker compose build claude

echo
echo "Done. Run 'make restart' to swap the running container to the new image."
