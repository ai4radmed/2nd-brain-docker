# Claude Code 호스트 설치 가이드 — WSL2 native

WSL2 ext4 native 환경에 Claude Code CLI 를 설치·인증·운영하는 단계별 가이드. 컨테이너 (`sb-claude`) 가 아닌 **호스트 직접 설치** 절차이며, 이 호스트 install 이 [`container-update-guide.md`](container-update-guide.md) 의 "버전 진실의 원천" 역할을 한다.

## 목적·범위

- **무엇을 다루는가**: 호스트 native 설치 + OAuth 로그인 + PATH·환경변수 + 자동 업데이트 디자인 + 검증
- **무엇을 안 다루는가**: 컨테이너 빌드 (별도: [`container-update-guide.md`](container-update-guide.md)), Claude Code 자체 사용법, 정책 (managed-settings)
- **누구에게**: 재구축 시 Dr. Ben + 같은 패턴을 따라 운영하는 다른 사용자

## 전제

- **WSL2 ext4 native** Ubuntu (22.04 또는 24.04). Windows 측이 아닌 **WSL2 셸 안에서 설치**.
- **Node.js 22+ (24 권장)** — Claude Code 가 Node 런타임에 의존. 설치 시점에 `node` 가 PATH 에 있어야 함.
  - Node 미설치 시: `2nd-brain-vault-guide` 의 `wsl2-nodejs-setup.md` 또는 [nvm 공식](https://github.com/nvm-sh/nvm) 의 절차로 nvm + LTS 먼저 셋업.
- **인터넷**: `claude.ai`, `api.anthropic.com` 으로 outbound HTTPS 가능.
- **Claude Pro/Max 구독** 또는 **Anthropic API key**.

검증:
```bash
node --version    # v22.x 또는 v24.x
npm --version
which curl
```

## 설치 디자인 — Native installer 패턴

Claude Code 의 설치 모델은 두 layer:

```
[npm bootstrap]                              [Native binary]
  npm install -g @anthropic-ai/claude-code   →  claude install <ver>
  (entry-point 만 설치)                          (실제 self-contained 바이너리)
        │                                              │
        ▼                                              ▼
  /usr/.../bin/claude                          ~/.local/share/claude/versions/<ver>/
  (PATH 우선순위 낮음, 폴백)                    ~/.local/bin/claude → versions/<ver> (symlink)
                                               (PATH 우선순위 높음, 실제 실행 대상)
```

**Native install 의 장점**:
- 사용자 home 안 (`~/.local/`) — root 권한 불필요, 자동 업데이트 가능
- self-contained (Node 바이너리 + 의존성 모두 한 디렉토리)
- 여러 버전 공존 — symlink 만 바꾸면 즉시 전환·롤백
- 컨테이너 (`sb-claude`) 도 **동일 메커니즘** 으로 깔리므로 호스트·컨테이너 인지 부하 통일

## 설치 — 두 옵션

### 옵션 A — 공식 install 스크립트 (가장 단순, 권장)

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

자동으로:
1. 최신 Claude Code 다운로드
2. `~/.local/share/claude/versions/<latest>/` 에 unpack
3. `~/.local/bin/claude` symlink 생성
4. PATH 설정 안내 출력 (필요 시)

설치 후 새 셸 또는 `source ~/.bashrc` 로 PATH 활성화.

### 옵션 B — npm + claude install (특정 버전 핀)

특정 버전을 명시하거나 컨테이너 빌드와 동일 흐름으로 가고 싶을 때:

```bash
npm install -g @anthropic-ai/claude-code@2.1.128
claude install 2.1.128
```

- Step 1: npm 으로 entry-point 만 설치 (npm-global 경로)
- Step 2: native installer 호출 → `~/.local/share/claude/versions/2.1.128/` 에 self-contained 설치 + symlink
- 결과는 옵션 A 와 동일하되 버전 명시

이 패턴은 컨테이너의 `Dockerfile` 과 정확히 같은 흐름:
```dockerfile
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
RUN claude install ${CLAUDE_CODE_VERSION}
```

## 설치 결과 — 디스크 layout

```
~/.local/
├── bin/
│   └── claude → ~/.local/share/claude/versions/<active>/   (symlink, PATH 노출)
└── share/claude/
    └── versions/
        ├── 2.1.121/   (옛 버전, 롤백용 보존)
        ├── 2.1.123/
        ├── 2.1.126/
        └── 2.1.128/   (현재 active — 약 240 MB)

~/.claude/                                        (사용자 데이터)
├── .credentials.json    (chmod 600 — OAuth access·refresh·expires)
├── settings.json        (UI·권한·모델 선택 등)
├── CLAUDE.md            (글로벌 instructions)
├── history.jsonl        (대화 이력)
├── sessions/            (세션별 컨텍스트)
├── file-history/        (편집한 파일들 히스토리)
├── plans/               (Plan mode 산출물)
├── tasks/               (TaskCreate 결과)
├── todos/               (todo 추적)
├── projects/            (프로젝트별 설정)
├── shell-snapshots/     (셸 환경 스냅샷)
├── telemetry/, paste-cache/, downloads/, plugins/
└── backups/             (자동 백업)
```

각 버전 디렉토리는 **약 240 MB** (Node 바이너리 + 의존성 포함). 옛 버전 누적되니 주기적 정리 검토 (단, 롤백 가능성 고려해서 최근 3-4개는 보존 권장).

## 첫 실행 + OAuth 로그인

```bash
claude
```

첫 실행 시 OAuth 흐름:
1. 터미널에 URL 출력
2. 브라우저로 그 URL 열기 (자동 또는 수동 paste)
3. claude.ai 에서 로그인 + 권한 동의
4. 콜백 코드 터미널에 paste
5. `~/.claude/.credentials.json` 에 OAuth access·refresh·expires 저장 (chmod 600)
6. 즉시 사용 가능 — 대화 시작 또는 `Ctrl+D` 로 종료

API key 사용자는 `claude` 실행 전 환경변수 설정:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

## PATH 및 환경변수

### PATH 설정

`~/.local/bin/` 이 PATH 에 있어야 함. 대부분의 Ubuntu 셸은 자동 포함하지만 확인:
```bash
echo "$PATH" | tr ':' '\n' | grep -F ".local/bin"
```

없으면 `~/.bashrc` 에 추가:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
exec bash
```

### 주요 환경변수 (선택)

| 변수 | 용도 |
|---|---|
| `ANTHROPIC_API_KEY` | OAuth 대신 API key 사용 시 |
| `CLAUDE_CODE_OAUTH_TOKEN` | CI 등 헤드리스 환경의 OAuth 토큰 직접 주입 |
| `CLAUDE_CONFIG_DIR` | 기본 `~/.claude/` 가 아닌 다른 경로 사용 시 |
| `DISABLE_AUTOUPDATER` | `1` 로 설정 시 자동 업데이트 차단 (호스트에선 보통 미설정 — 자동 업데이트가 디자인) |
| `DISABLE_TELEMETRY` | telemetry 차단 |

### OAuth 토큰의 위치 (보안 의식)

`~/.claude/.credentials.json` 은 **권한 600**, dotfile (앞 점). `ls ~/.claude/` (점 없는 일반 ls) 에 안 보임 — `ls -la` 또는 `ls ~/.claude/.credentials.json` 으로 명시 확인. 자세한 인증 토폴로지: `2nd-brain-vault/knowledge/02_areas/brain-system/openclaw-gogcli-integration.md` §1 의 정체성 A.

## 자동 업데이트 — 호스트의 디자인

호스트는 `DISABLE_AUTOUPDATER` 미설정이 default → Claude CLI 가 새 버전 release 시 자동으로 다운로드·설치. 새 버전이 `~/.local/share/claude/versions/<new>/` 에 들어가고 `~/.local/bin/claude` symlink 가 갱신.

**왜 호스트는 자동 업데이트를 켜는가**:
- 사용자 home 경로 (`~/.local/`) — 권한 충돌 없음
- 새 버전이 옛 버전을 덮어쓰지 않음 (디렉토리 분리, symlink swap)
- 롤백이 명확 — symlink 만 옛 버전으로 돌리면 즉시 복귀

**컨테이너는 반대로 차단**:
- 컨테이너 안 self-update 는 쓰기 레이어로 들어가 휘발 + 같은 이미지인데 시작 시점 따라 버전이 달라져 immutability 깨짐
- → `compose.yml` 의 `DISABLE_AUTOUPDATER: "1"` + `.env` 의 `CLAUDE_CODE_VERSION` 핀
- 호스트의 자동 업데이트를 의도적으로 따라잡으려면 [`container-update-guide.md`](container-update-guide.md) 의 `make sync` 흐름 사용

## 검증 체크리스트

```bash
# 1. 바이너리 위치·버전
which claude                                # /home/<user>/.local/bin/claude
claude --version                            # 2.1.x (Claude Code)

# 2. native install 구조
ls -la ~/.local/bin/claude                  # symlink 확인
ls ~/.local/share/claude/versions/          # 설치된 버전들

# 3. OAuth 자격증명
ls -la ~/.claude/.credentials.json          # -rw------- (chmod 600)

# 4. 첫 호출 정상 작동 (대화·탈출)
echo "exit" | claude --print                # 인증·연결 즉시 검증

# 5. PATH 우선순위 (native 가 npm-global 보다 앞에)
type -a claude                              # 첫 결과가 ~/.local/bin/claude
```

## 트러블슈팅

### `claude: command not found` (설치 후 새 셸)

원인: `~/.local/bin/` 이 PATH 에 없음.

조치:
```bash
grep -q '\.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
exec bash
```

### nvm 환경에서 claude 가 다른 Node 버전 사용

원인: nvm 의 default node 와 claude install 시점의 node 가 다름.

조치: 일관된 default 셋업 후 재설치:
```bash
nvm alias default 24
nvm use default
claude install $(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
```

### 자동 업데이트가 안 됨

확인:
```bash
ls -la ~/.local/bin/claude              # 최근 mtime 인지
ls ~/.local/share/claude/versions/      # 새 버전이 들어왔는지
```

수동 업데이트:
```bash
# 옵션 A: 공식 스크립트 재실행
curl -fsSL https://claude.ai/install.sh | bash

# 옵션 B: npm 으로 강제
npm update -g @anthropic-ai/claude-code
claude install $(npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
```

### OAuth 로그인 실패 — 비-TTY 환경

원인: Claude Code 이 도구 호출 (다른 LLM agent 의 subprocess 등) 처럼 TTY 없는 환경에선 OAuth 콜백 흐름 안됨.

조치: **Dr. Ben 본인 셸에서 직접** `claude /login` 실행. 또는 `CLAUDE_CODE_OAUTH_TOKEN` 환경변수로 토큰 직접 주입.

### `~/.claude/` 영역의 disk 사용량 폭증

원인: `history.jsonl`·`file-history/`·`sessions/` 누적.

조치 (안전하게):
```bash
du -sh ~/.claude/*                       # 어디가 큰지 확인
# 큰 항목 정리 (백업 후):
mkdir -p ~/.claude.archive/$(date +%Y%m%d)
mv ~/.claude/file-history/<old-stuff> ~/.claude.archive/$(date +%Y%m%d)/
```

`.credentials.json`·`settings.json`·`CLAUDE.md` 는 **절대 삭제 금지**.

### 옛 버전 디렉토리 누적 — 디스크 청소

```bash
ls -lt ~/.local/share/claude/versions/    # 최신 순
# 최근 3개만 남기고 정리:
ls -t ~/.local/share/claude/versions/ | tail -n +4 | xargs -I {} rm -rf ~/.local/share/claude/versions/{}
```

⚠ 현재 active 버전 (`~/.local/bin/claude` 가 가리키는 것) 은 절대 지우지 말 것. `readlink ~/.local/bin/claude` 로 확인.

## 다중 기기 운영 — `~/.claude/` 동기 패턴 (선택)

여러 머신에서 같은 Claude Code 설정 (commands·skills·CLAUDE.md) 공유 원할 시:

**옵션 1 — symlink 로 외부 동기 영역 참조**:
```bash
# 예: Google Drive 의 공유 설정 디렉토리를 symlink
ln -sf /mnt/d/Gdrive/<your-cloud>/claude-config/shared/commands ~/.claude/commands
ln -sf /mnt/d/Gdrive/<your-cloud>/claude-config/shared/skills ~/.claude/skills
```

설정 일부만 공유 (예: `commands/`, `skills/`, `CLAUDE.md`) — credentials·sessions·history 는 머신별 독립.

**옵션 2 — Syncthing 으로 vault 와 함께 동기**: vault 옆에 `claude-config/` 디렉토리 두고 같은 Syncthing folder 로 동기. 다중 기기 일관성에 가장 강력하나 셋업 비용 있음.

## 컨테이너와의 관계

호스트 install 이 끝나면 → 컨테이너 빌드 시 **호스트의 현재 버전을 추종**:

```bash
cd ~/projects/2nd-brain-docker
make sync && make restart && sb-healthcheck
```

자세한 컨테이너 흐름: [`container-update-guide.md`](container-update-guide.md).

호스트와 컨테이너의 install 메커니즘 자체는 **동일** (둘 다 `claude install <ver>` 의 native installer 호출) — 인지 부하 통일이 디자인 의도.

## 관련 문서

- [`container-update-guide.md`](container-update-guide.md) — 컨테이너 측 업데이트 흐름. 본 호스트 install 이 truth-of-record.
- [`README.md`](../README.md) "버전 업그레이드" — quick reference (호스트·컨테이너 한 페이지 요약)
- [`openclaw-setup.md`](openclaw-setup.md) — OpenClaw 호스트 설치 (Claude CLI 와 짝). Step 3 onboarding 이 Claude CLI OAuth 자격증명을 import.
- `2nd-brain-vault/knowledge/02_areas/brain-system/tools/claude-code/notes/claude-code-devcontainer.md` — Anthropic 공식 devcontainer 패턴 비교 (vault, 비공개)
- `2nd-brain-vault-guide/...wsl2-nodejs-setup.md` (있다면) — Node 24 셋업 (전제)

## 변경 이력

- **2026-05-06**: 초안. 호스트 native installer 패턴 + 두 설치 옵션 + 디스크 layout + OAuth + PATH·env + 자동 업데이트 디자인 + 검증 + 8 트러블슈팅 케이스 정리.
