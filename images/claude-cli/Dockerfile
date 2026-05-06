# Claude Code 는 Bun 으로 컴파일된 self-contained native binary (240MB) 라
# Node·npm runtime 의존성 0. 호스트와 동일하게 install.sh 사용 — 인지부하 통일.
FROM debian:trixie-slim

ARG UID=1000
ARG GID=1000
ARG CLAUDE_CODE_VERSION

# install.sh 실행에 필요한 도구 + Claude CLI runtime 보조 도구.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates ripgrep less curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "$GID" user \
    && useradd -u "$UID" -g "$GID" -m -s /bin/bash user

USER user

# 공식 권장 install.sh — 호스트와 동일 메커니즘 + `bash -s <ver>` 로 버전 핀.
# 결과: ~/.local/share/claude/versions/${VER}/ self-contained binary,
# ~/.local/bin/claude symlink. self-update 는 compose.yml 의
# DISABLE_AUTOUPDATER=1 로 차단 (이미지 immutability 보존).
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

ENV PATH="/home/user/.local/bin:${PATH}"

RUN mkdir -p /home/user/.claude
WORKDIR /home/user/projects/2nd-brain-vault
CMD ["sleep", "infinity"]
