.PHONY: build sync up up-gog down restart restart-gog shell logs clean install-wrapper install-systemd \
        build-brain-pdf up-brain-pdf down-brain-pdf shell-brain-pdf run-brain-pdf

UID := $(shell id -u)
GID := $(shell id -g)
export UID GID

# compose.gog.yml 을 합쳐 컨테이너 gogcli 활성화 (Option B 셋업 완료 사용자용).
# 자세한 셋업 절차: docs/gogcli-container-setup.md
COMPOSE_GOG := -f compose.yml -f compose.gog.yml

# brain-pdf 의 compose 체인은 PC 환경 (NVIDIA 유무) 에 따라 다름 — scripts/detect-compose.sh
# 가 nvidia-smi + docker runtime 을 검사해 GPU overlay 를 자동 포함/제외.
# 양 PC (데스크탑 kimbi RTX 3060 / 노트북 Intel Arc) 에서 같은 타겟 사용 가능.
# Override: `BRAIN_PDF_FORCE_VARIANT=gpu|cpu make ...` (디버깅 / 감지 misfire).
COMPOSE_BRAIN_PDF := $(shell ./scripts/detect-compose.sh)

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
# 양 PC 공통 타겟. detect-compose.sh 가 NVIDIA 환경 자동 감지.
#
# Override (드물게):
#   BRAIN_PDF_FORCE_VARIANT=cpu make run-brain-pdf   # GPU 있는 PC 에서 강제 CPU
#   BRAIN_PDF_FORCE_VARIANT=gpu make build-brain-pdf  # 감지 실패 시 강제 GPU

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

# Ephemeral 일회성 실행 — 인자를 그대로 forward.
# 예: `make run-brain-pdf ARGS="brain-pdf parse-docling /home/user/projects/2nd-brain-vault/sources/00_inbox/sample.pdf"`
run-brain-pdf:
	docker compose $(COMPOSE_BRAIN_PDF) run --rm brain-pdf $(ARGS)
