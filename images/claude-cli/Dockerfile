FROM node:24.15.0-slim

ARG UID=1000
ARG GID=1000
ARG CLAUDE_CODE_VERSION

# Bootstrap: npm 으로 동일 버전 설치 (`claude install` 호출용 entry point).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates ripgrep less curl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

RUN userdel -r node 2>/dev/null || true \
    && groupdel node 2>/dev/null || true \
    && groupadd -g "$GID" user \
    && useradd -u "$UID" -g "$GID" -m -s /bin/bash user

USER user

# Native install — 호스트와 동일 메커니즘. ~/.local/share/claude/versions/${VER}/
# 에 self-contained 바이너리, ~/.local/bin/claude 가 symlink. PATH 우선순위로
# native 가 npm-global(/usr/local/bin) 보다 먼저 선택됨.
RUN claude install ${CLAUDE_CODE_VERSION}
ENV PATH="/home/user/.local/bin:${PATH}"

RUN mkdir -p /home/user/.claude
WORKDIR /home/user/projects/2nd-brain-vault
CMD ["sleep", "infinity"]
