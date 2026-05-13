.PHONY: build sync up up-gog down restart restart-gog shell logs clean install-wrapper install-systemd \
        build-brain-pdf up-brain-pdf down-brain-pdf shell-brain-pdf run-brain-pdf \
        build-brain-pdf-gpu up-brain-pdf-gpu run-brain-pdf-gpu

UID := $(shell id -u)
GID := $(shell id -g)
export UID GID

# compose.gog.yml 을 합쳐 컨테이너 gogcli 활성화 (Option B 셋업 완료 사용자용).
# 자세한 셋업 절차: docs/gogcli-container-setup.md
COMPOSE_GOG := -f compose.yml -f compose.gog.yml

# compose.brain-pdf.yml 을 합쳐 Docling+MinerU PDF 파서 서비스 활성화.
# Phase 1 기본 사용은 ephemeral (`run-brain-pdf` 또는 `docker compose run --rm brain-pdf ...`).
# RAM 여유 시 daemon (`up-brain-pdf`) 으로 모델 warm-keep.
COMPOSE_BRAIN_PDF := -f compose.yml -f compose.brain-pdf.yml

# GPU 오버레이 추가 — nvidia-container-toolkit 설치된 PC (데스크탑 kimbi RTX 3060) 에서만 사용.
# `*-brain-pdf-gpu` 타겟이 본 합성을 사용.
COMPOSE_BRAIN_PDF_GPU := -f compose.yml -f compose.brain-pdf.yml -f compose.brain-pdf.gpu.yml

build:
	docker compose build

# 호스트의 claude 버전에 컨테이너 이미지를 맞춰 재빌드.
# 호스트가 진실의 원천 — auto-update 가 호스트 버전을 끌어올리면 그걸 따라간다.
sync:
	./scripts/bin/sync-claude-version.sh

up:
	docker compose up -d

up-gog:
	docker compose $(COMPOSE_GOG) up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

restart-gog:
	docker compose down
	docker compose $(COMPOSE_GOG) up -d

shell:
	docker exec -it sb-claude /bin/bash

logs:
	docker compose logs -f claude

clean:
	docker compose down -v
	docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^2nd-brain/claude-cli:' | xargs -r docker rmi 2>/dev/null || true

install-wrapper:
	install -m 0755 scripts/2nd-brain-docker $(HOME)/.local/bin/2nd-brain-docker
	@echo "installed: $(HOME)/.local/bin/2nd-brain-docker"

install-systemd:
	install -d $(HOME)/.config/systemd/user
	install -m 0644 scripts/sb-claude.service $(HOME)/.config/systemd/user/sb-claude.service
	systemctl --user daemon-reload
	systemctl --user enable --now sb-claude.service
	@echo
	@echo "Boot persistence requires (one-time, sudo):"
	@echo "    sudo loginctl enable-linger $$USER"

# ── brain-pdf (Docling + MinerU PDF parser) ──────────────────────────────────

build-brain-pdf:
	docker compose $(COMPOSE_BRAIN_PDF) build brain-pdf

# Daemon 모드 — 모델 RAM 상주 (4~8GB). 14GB WSL2 한도에서는 sb-claude 와 합산 점검 필요.
up-brain-pdf:
	docker compose $(COMPOSE_BRAIN_PDF) up -d brain-pdf

down-brain-pdf:
	docker compose $(COMPOSE_BRAIN_PDF) stop brain-pdf
	docker compose $(COMPOSE_BRAIN_PDF) rm -f brain-pdf

shell-brain-pdf:
	docker exec -it sb-brain-pdf /bin/bash

# Ephemeral 일회성 실행 — 인자를 그대로 forward. 예: `make run-brain-pdf ARGS="parse-docling /home/user/projects/2nd-brain-vault/sources/00_inbox/sample.pdf"`
run-brain-pdf:
	docker compose $(COMPOSE_BRAIN_PDF) run --rm brain-pdf $(ARGS)

# GPU variants — 데스크탑 (RTX 3060) 전용. compose.brain-pdf.gpu.yml 합성.
build-brain-pdf-gpu:
	docker compose $(COMPOSE_BRAIN_PDF_GPU) build brain-pdf

up-brain-pdf-gpu:
	docker compose $(COMPOSE_BRAIN_PDF_GPU) up -d brain-pdf

run-brain-pdf-gpu:
	docker compose $(COMPOSE_BRAIN_PDF_GPU) run --rm brain-pdf $(ARGS)
