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
├── compose.gog.yml          # opt-in overlay: 컨테이너 gogcli 활성화 (Option B 셋업 후)
├── docs/
│   └── gogcli-container-setup.md  # 컨테이너 gogcli 권한분리 셋업 가이드 (공개)
├── images/
│   ├── claude-cli/          # Claude CLI 이미지 빌드
│   │   └── Dockerfile
│   └── squid/               # (현재 미사용) egress 프록시 자산 — 2026-05 운영 마찰로 제거, 자료 보존만
│       ├── Dockerfile
│       └── squid.conf
├── policy/
│   └── managed-settings.json  # (현재 비활성) Claude Code 최우선 정책 — 단순화 검증 단계, 안정화 후 재도입 검토
├── scripts/
│   ├── 2nd-brain-docker     # 호스트 PATH 래퍼 (데몬으로 진입)
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

2nd-brain-docker            # 첫 실행 시 /login 1회 (OAuth 토큰은 claude-state 에 영구화)
```

→ 이미 셋업된 머신에서 다시 실행해도 *no-op* 에 가까움. 다른 머신·재셋업 시 같은 블록 그대로 사용 가능.

## 사용

```bash
2nd-brain-docker            # 어디서 호출하든 데몬 안의 vault 에서 claude 실행
2nd-brain-docker --resume   # 대화 재개 등 인자 전달
make up                     # 데몬 시작 (수동)
make down                   # 데몬 정지
make restart                # 재기동
make shell                  # 데몬 컨테이너에 bash 진입
make logs                   # claude 컨테이너 로그
make sync                   # 호스트 claude 버전에 컨테이너 핀 맞춰 재빌드

# 컨테이너에서 gogcli 사용 (Option B 셋업 후 — docs/gogcli-container-setup.md 참조)
make up-gog                 # gog overlay 포함 기동
make restart-gog            # gog overlay 포함 재기동
```

호스트 PWD 가 `~/projects/2nd-brain-vault/...` 안에 있으면 `2nd-brain-docker` 가 컨테이너에서 동일 상대 경로로 들어가고, 그 외에는 vault 루트에서 시작한다.

## 버전 업그레이드

호스트 Claude Code 는 native installer 로 `~/.local/bin/claude` 에 깔려 있고 사용자 소유 경로라 자동 업데이트가 잘 동작한다. 컨테이너는 그 호스트 버전을 따라가도록 핀+재빌드 모델로 운영 — **호스트 = 버전 진실의 원천**.

자동(권장):

```bash
make sync       # 호스트 claude --version 추출 → .env 의 CLAUDE_CODE_VERSION 갱신 → 재빌드
make restart    # 새 이미지로 컨테이너 교체
```

수동:

```bash
# 1) .env 의 CLAUDE_CODE_VERSION 을 원하는 버전으로 수정
# 2) 재빌드 + 재기동
make build && make restart
```

설계:

- 컨테이너 안에서는 호스트와 **동일한 native installer** 사용 (`claude install ${VER}`) — 설치 경로·layout 통일로 인지 부하 감소.
- npm-global 은 bootstrap (= `claude install` 호출용 entry point) 로만 잔존, PATH 우선순위로 native (`/home/user/.local/bin/claude`) 가 선택됨.
- 런타임 self-update 는 `DISABLE_AUTOUPDATER=1` (compose.yml) 로 차단. 컨테이너 안에서 자기 자신을 덮어써봐야 쓰기 레이어로 들어가 휘발 + 같은 이미지인데 시작 시점에 따라 버전이 달라져 불변성이 깨지기 때문.
- 갱신 경로는 오직 **이미지 재빌드** — 의도적인 사람의 결정이 git 히스토리에 남는다.

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

## 컨테이너에서 Google Workspace 사용 (옵션 B — 권한 분리)

기본값 (이 저장소의 base `compose.yml`) 은 컨테이너에 gogcli 를 마운트하지 않는다 — 호스트 native Claude 만 Google Workspace 작업을 처리하는 양분 운영. 컨테이너에서도 Gmail/Calendar/Drive 작업이 필요하면 별도 OAuth client 와 keyring 으로 **권한을 분리**해서 활성화하는 것을 권장한다 (호스트의 자격증명을 그대로 주입하지 않음 — 침해 시 폭발 반경 한정).

상세 절차: [`docs/gogcli-container-setup.md`](./docs/gogcli-container-setup.md). 위협 모델·GCP OAuth client 생성·scope 설계·`compose.gog.yml` 적용·검증·revoke 절차 포함.

## 데이터 경로

호스트와 컨테이너가 **동일 상대 경로** (`~/projects/...`) 를 사용 — `~` 가 호스트(`/home/ben`) 와 컨테이너(`/home/user`) 각자의 home 으로 풀리므로 vault `CLAUDE.md` 의 `@~/projects/...` import 가 양쪽에서 동일하게 작동.

| 항목 | 경로 (호스트·컨테이너 공통) | 마운트 모드 |
|---|---|---|
| vault (.env `SB_DATA`) | `~/projects/2nd-brain-vault` (WSL2 ext4 native, Syncthing 동기) | RW |
| guide (.env `SB_GUIDE`) | `~/projects/2nd-brain-vault-guide` (git 관리, 공개) | RW (vault 에서 안정화된 지침을 상향) |

vault 의 `CLAUDE.md` 는 guide 문서들을 `@~/projects/2nd-brain-vault-guide/...` 로 `@`-import 하는 *얇은 layer* 패턴으로 운영. 절대 경로(`/home/ben/...` / `/home/user/...`) 직접 사용 금지.
