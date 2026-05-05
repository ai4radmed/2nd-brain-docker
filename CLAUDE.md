# 2nd-brain-docker — 실행환경 구축 자동화

`2nd-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산 저장소.

## 짝 프로젝트와의 관계

이 저장소는 **실행환경 구축 자동화**만 담당한다. 운영 방법론과 실제 데이터는 별도 짝 저장소에 있다.

| 저장소 | 역할 | 위치 | 공개 |
|---|---|---|---|
| **2nd-brain-docker** (이곳) | Docker 이미지·compose·Makefile — 컨테이너로 실행환경을 빌드·기동 | GitHub `ai4radmed/2nd-brain-docker`, 로컬 `~/projects/2nd-brain-docker/` | 공개 |
| **2nd-brain-vault-guide** (짝) | PARA 운영 방법론·템플릿·빈 vault 골격 — 외부인이 자기 시스템 부트스트랩에 사용 | GitHub `ai4radmed/2nd-brain-vault-guide`, 로컬 `~/projects/2nd-brain-vault-guide/` | 공개 |
| **2nd-brain-vault** (짝, vault) | knowledge·sources 데이터, brainify 결과물 — Ben 본인의 정본 | 로컬 `~/projects/2nd-brain-vault/` (WSL2 ext4 native) · Windows에선 `\\wsl.localhost\Ubuntu\home\ben\projects\2nd-brain-vault\` · Syncthing 동기 + 로컬 git 으로 버전관리 | 비공개 |

비유:

- **docker** = 건물(실행환경)을 짓는 도면
- **vault-guide** = 건물 안에서의 생활 규칙·가구 배치도 (외부인도 따라할 수 있도록 일반화된 형태)
- **vault** = 그 건물에서 실제로 살아가는 한 사람의 살림살이

## 권위 문서 — 영역별 정본

권위가 한 곳에 있지 않고 영역별로 나뉜다.

| 영역 | 정본 위치 |
|---|---|
| 데이터 운영 규약 (PARA, companion note, 파일명, 동기화 규칙) | `~/projects/2nd-brain-vault/CLAUDE.md` (얇은 layer + guide `@`-import) |
| 공개 방법론 (외부인 onboarding, vault 골격, 일반화된 워크플로우) | `~/projects/2nd-brain-vault-guide/CLAUDE.md` 및 `2nd-brain-vault-guide/README.md` |
| 실행환경 자산 (마운트 경로, UID 매핑, compose 패턴) | 이 저장소 (자기참조) |

이 저장소(Dockerfile·compose.yml·Makefile)에서 마운트 경로·user 매핑·작업 디렉토리 등을 변경할 경우 **반드시 `2nd-brain-vault/CLAUDE.md` 의 Docker 운영 규칙과 동기화**할 것. 두 곳이 어긋나면 컨테이너 안에서 경로 번역이 깨진다.

## 운영 흐름

1. `make build` → claude-cli 이미지 빌드. `CLAUDE_CODE_VERSION` 은 `.env` 에서 명시적으로 핀 — `latest` 금지. 이미지 안에서 **호스트와 동일한 native installer** (`claude install ${VER}`) 로 `~/.local/share/claude/versions/${VER}/` 에 설치되며, npm-global 은 그 명령을 호출하기 위한 bootstrap 로만 남는다. 런타임 self-update 는 `DISABLE_AUTOUPDATER=1` (compose.yml) 로 차단 — 갱신 경로는 오직 재빌드. 호스트 버전이 자동으로 올라간 뒤에는 `make sync` 가 호스트의 `claude --version` 을 읽어 `.env` 의 `CLAUDE_CODE_VERSION` 을 갱신하고 이미지를 재빌드한다.
2. `make up` → claude 데몬 컨테이너 기동:
   - `sb-claude` (RW 데몬, `sleep infinity`) — vault `~/projects/2nd-brain-vault` (RW) + guide `~/projects/2nd-brain-vault-guide` (RW — 상향 운영) 마운트
   - egress whitelist (`sb-egress` / squid) 는 2026-05 운영 마찰로 제거 — `images/squid/` 는 보존되어 있으나 미사용
3. `make install-wrapper` → 호스트 PATH 에 `2nd-brain-docker` 설치. `make install-systemd` + `sudo loginctl enable-linger $USER` → 부팅 자동기동.
4. 일상 사용: 호스트 어디서든 `2nd-brain-docker` 호출 → 실행 중인 데몬 안 vault 에서 Claude CLI 실행. RW/RO 분리 모델 폐기 (A3) — 단일 RW 데몬.
5. vault 의 CLAUDE.md 는 *얇은 layer* — 자기 운영 규칙 + guide 문서들을 `@~/projects/2nd-brain-vault-guide/...` 로 `@`-import. `~` 가 호스트(`/home/ben`) 와 컨테이너(`/home/user`) 각자의 home 으로 풀려 양쪽에서 동일 import 작동.
6. 컨테이너 안의 모든 작업 규약은 그 CLAUDE.md (+ import 된 guide) 를 따름.

격리 정책 현황: non-root, `cap_drop: ALL`, `no-new-privileges`. egress 화이트리스트(squid)·`read_only`/`tmpfs`·`mem_limit`/`cpus`·managed-settings 정책(`policy/managed-settings.json`) 모두 현재 비활성 — 컨테이너 단순화·디버깅을 위해 일시 제거. 컨테이너·UID·capability 차원 격리만 유지하고, prompt injection → 외부 exfiltration 차단은 향후 permission `deny`/`ask` 정책으로 보완.

런타임 환경변수 (compose.yml `environment:`):

- `NODE_OPTIONS=--max-old-space-size=4096` — V8 heap 4GB. 기본 1.5GB 로는 Opus 4.7 + vault 컨텍스트 + plugin/MCP 처리 시 GC pause → SSE idle timeout → silent retry loop 발생. Anthropic 공식 `.devcontainer` 와 trailofbits/claude-code-devcontainer 동일 설정 — 표준 운영값으로 취급, 노이즈 아님.
- `CLAUDE_CONFIG_DIR=/home/user/.claude` — Claude Code 가 config dir 추정 비용 절약.

상세 사용법은 `README.md` 참조.
