.PHONY: build up down restart shell logs clean install-wrapper install-systemd

UID := $(shell id -u)
GID := $(shell id -g)
export UID GID

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

shell:
	docker exec -it sb-claude /bin/bash

logs:
	docker compose logs -f claude

clean:
	docker compose down -v
	docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^2nd-brain/claude-cli:' | xargs -r docker rmi 2>/dev/null || true

install-wrapper:
	install -m 0755 scripts/bclaude $(HOME)/.local/bin/bclaude
	@echo "installed: $(HOME)/.local/bin/bclaude"

install-systemd:
	install -d $(HOME)/.config/systemd/user
	install -m 0644 scripts/sb-claude.service $(HOME)/.config/systemd/user/sb-claude.service
	systemctl --user daemon-reload
	systemctl --user enable --now sb-claude.service
	@echo
	@echo "Boot persistence requires (one-time, sudo):"
	@echo "    sudo loginctl enable-linger $$USER"
