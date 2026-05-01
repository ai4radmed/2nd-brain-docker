.PHONY: build rw ro shell down logs clean

UID := $(shell id -u)
GID := $(shell id -g)
export UID GID

build:
	docker compose build

rw:
	docker compose run --rm claude

ro:
	docker compose run --rm claude-ro

shell:
	docker compose run --rm --entrypoint /bin/bash claude

down:
	docker compose down

logs:
	docker compose logs -f

clean:
	docker compose down -v
	docker rmi 2nd-brain/claude-cli:latest 2>/dev/null || true
