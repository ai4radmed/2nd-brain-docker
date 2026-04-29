FROM node:22-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        ripgrep \
        less \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN userdel -r node 2>/dev/null || true \
    && groupdel node 2>/dev/null || true \
    && groupadd -g "$GID" user \
    && useradd -u "$UID" -g "$GID" -m -s /bin/bash user

RUN npm install -g @anthropic-ai/claude-code

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER user
RUN mkdir -p /home/user/.claude
WORKDIR /workspace/second-brain

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
