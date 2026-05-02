# 2nd-brain-docker

`2nd-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산. **2nd-brain-vault 전용 데몬 컨테이너** 모델로 운영한다.

## 짝 저장소

| 저장소 | 역할 |
|---|---|
| **2nd-brain-docker** (이곳) | Docker 이미지·compose·Makefile (실행환경) |
| **[2nd-brain-vault-guide](https://github.com/ai4radmed/2nd-brain-vault-guide)** | PARA 운영 방법론·템플릿·빈 vault 골격 (공개 방법론 자산) |
| **2nd-brain-vault** | 개인 knowledge·sources 데이터 (각자 비공개 운영, Syncthing 동기 권장) |

자세한 관계 정의는 [`CLAUDE.md`](./CLAUDE.md) 참조.

## 구조

```
.
├── compose.yml              # 서비스 정의 (claude 데몬)
├── images/
│   ├── claude-cli/          # Claude CLI 이미지 빌드
│   │   └── Dockerfile
│   └── squid/               # (현재 미사용) egress 프록시 자산 — 2026-05 운영 마찰로 제거, 자료 보존만
│       ├── Dockerfile
│       └── squid.conf
├── policy/
│   └── managed-settings.json  # (현재 비활성) Claude Code 최우선 정책 — 단순화 검증 단계, 안정화 후 재도입 검토
├── scripts/
│   ├── bclaude              # 호스트 PATH 래퍼 (데몬으로 진입)
│   └── sb-claude.service    # systemd-user 부팅 자동기동
├── secrets/                 # API 키·토큰 (gitignored)
├── .env.example             # 환경변수 템플릿
└── Makefile                 # 단축 명령
```

## 첫 셋업

전체 시퀀스가 멱등(idempotent) — 처음이든 재실행이든 같은 결과.

```bash
[ -f .env ] || cp .env.example .env   # 이미 있으면 건너뜀 (수정한 .env 보호)
# 처음이면 .env 편집 — UID/GID 확인 ($(id -u), $(id -g)), CLAUDE_CODE_VERSION 등

make build && make up
make install-wrapper && make install-systemd
sudo loginctl enable-linger $USER

bclaude                     # 첫 실행 시 /login 1회 (OAuth 토큰은 claude-state 에 영구화)
```

→ 이미 셋업된 머신에서 다시 실행해도 *no-op* 에 가까움. 다른 머신·재셋업 시 같은 블록 그대로 사용 가능.

## 사용

```bash
bclaude                     # 어디서 호출하든 데몬 안의 vault 에서 claude 실행
bclaude --resume            # 대화 재개 등 인자 전달
make up                     # 데몬 시작 (수동)
make down                   # 데몬 정지
make restart                # 재기동
make shell                  # 데몬 컨테이너에 bash 진입
make logs                   # claude 컨테이너 로그
```

호스트 PWD 가 `~/projects/2nd-brain-vault/...` 안에 있으면 `bclaude` 가 컨테이너에서 동일 상대 경로로 들어가고, 그 외에는 vault 루트에서 시작한다.

## 버전 업그레이드

```bash
# 1) .env 의 CLAUDE_CODE_VERSION 을 새 버전으로 수정
# 2) 재빌드 + 재기동
make build && make restart
```

자동 업데이트 없음 — `npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` 로 빌드 타임에 핀, 런타임 업데이트 경로 없음. 의도적으로 사람이 결정하는 흐름.

## 인증

기본은 OAuth (`claude login`). 첫 실행 시 컨테이너 안에서 한 번 로그인하면 `claude-state` named volume 에 영속.

API 키 방식은 `secrets/README.md` 참조.

## 보안 모델

- **마운트 최소화**: `~/projects/2nd-brain-vault` (RW) + `~/projects/2nd-brain-vault-guide` (RW — vault → guide 상향 운영을 위해) 만 노출.
- **non-root**: `--user $(id -u):$(id -g)` 매핑.
- **cap_drop ALL** + **no-new-privileges**.

**현재 비활성 — 단순화·디버깅 단계** (재도입은 안정화 후 검토):

- `mem_limit` / `cpus` 자원 제한 제거.
- [`policy/managed-settings.json`](./policy/managed-settings.json) 의 Permission 정책 (자격증명·외부 송신·파괴적 명령·MCP destructive 도구 차단) 미적용 — 파일은 보존, 마운트 미연결.
- `read_only` / `tmpfs` 정책.
- egress 통제 — 이전엔 squid 도메인 화이트리스트(`sb-egress`)로 외부망을 막았으나, SSE keepalive buffering·5분 idle timeout 등 운영 마찰이 보안 가치를 초과해 2026-05 제거. `images/squid/` 자산은 재평가 시 출발점으로 보존.

**런타임 환경변수**: `NODE_OPTIONS=--max-old-space-size=4096` (V8 heap 4GB) + `CLAUDE_CONFIG_DIR=/home/user/.claude`. Anthropic 공식 `.devcontainer` 와 trailofbits/claude-code-devcontainer 동일 설정. 빠뜨리면 Opus 4.7 + 우리 컨텍스트 조합에서 첫 복잡 질문 silent hang(V8 GC → SSE idle timeout → CLI silent retry loop) 재발 — 표준 운영값으로 취급할 것.

## 데이터 경로

호스트와 컨테이너가 **동일 상대 경로** (`~/projects/...`) 를 사용 — `~` 가 호스트(`/home/ben`) 와 컨테이너(`/home/user`) 각자의 home 으로 풀리므로 vault `CLAUDE.md` 의 `@~/projects/...` import 가 양쪽에서 동일하게 작동.

| 항목 | 경로 (호스트·컨테이너 공통) | 마운트 모드 |
|---|---|---|
| vault (.env `SB_DATA`) | `~/projects/2nd-brain-vault` (WSL2 ext4 native, Syncthing 동기) | RW |
| guide (.env `SB_GUIDE`) | `~/projects/2nd-brain-vault-guide` (git 관리, 공개) | RW (vault 에서 안정화된 지침을 상향) |

vault 의 `CLAUDE.md` 는 guide 문서들을 `@~/projects/2nd-brain-vault-guide/...` 로 `@`-import 하는 *얇은 layer* 패턴으로 운영. 절대 경로(`/home/ben/...` / `/home/user/...`) 직접 사용 금지.
