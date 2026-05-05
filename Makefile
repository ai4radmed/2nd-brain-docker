.PHONY: build sync up up-gog down restart restart-gog shell logs clean install-wrapper install-systemd

UID := $(shell id -u)
GID := $(shell id -g)
export UID GID

# compose.gog.yml 을 합쳐 컨테이너 gogcli 활성화 (Option B 셋업 완료 사용자용).
# 자세한 셋업 절차: docs/gogcli-container-setup.md
COMPOSE_GOG := -f compose.yml -f compose.gog.yml

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
