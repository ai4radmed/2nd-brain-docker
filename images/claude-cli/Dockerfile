FROM node:24.15.0-slim

ARG UID=1000
ARG GID=1000
ARG CLAUDE_CODE_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates ripgrep less curl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

RUN userdel -r node 2>/dev/null || true \
    && groupdel node 2>/dev/null || true \
    && groupadd -g "$GID" user \
    && useradd -u "$UID" -g "$GID" -m -s /bin/bash user

USER user
RUN mkdir -p /home/user/.claude
WORKDIR /home/user/projects/2nd-brain-vault
CMD ["sleep", "infinity"]
