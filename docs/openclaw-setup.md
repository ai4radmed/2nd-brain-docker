# OpenClaw 셋업 — 2nd-brain Telegram 입구

새 머신에 OpenClaw 게이트웨이를 셋업하여 **Telegram → Claude 브리지**를 운영하는 단계별 가이드. 각 단계마다 검증 명령이 따로 있어 붙여넣기로 진행 가능.

## 목적·범위

- **무엇을 다루는가**: WSL2 native 에 OpenClaw 설치(npm method) + onboarding + 게이트웨이 systemd-user 등록 + Telegram 채널 페어링 + 자동 시작
- **무엇을 안 다루는가**: Docker 모드 설치 (필요 시 별도 가이드), Discord/iMessage 등 다른 채널, 다중 에이전트 구성
- **결정 근거·운영 맥락**: `2nd-brain-vault/knowledge/02_areas/brain-system/tools/openclaw/README.md`

## 정보 흐름

```
[사용자]
   │
   │  Telegram 메시지
   ▼
[@YourBot]  (BotFather 로 생성)
   │
   │  long polling
   ▼
[OpenClaw 게이트웨이]  127.0.0.1:18789  (systemd-user 로 자동 시작)
   │
   │  Anthropic API
   ▼
[Claude]
   │
   │  응답
   └─→ 같은 경로 역방향
```

## 전제

- WSL2 ext4 native (Ubuntu/Debian 계열). `~/projects/2nd-brain-vault/` 와 같은 호스트.
- 인터넷 outbound HTTPS (`openclaw.ai`, `api.anthropic.com`, `api.telegram.org`)
- Anthropic API key (또는 다른 provider key — onboarding 단계에서 선택)
- Telegram 사용 시: Telegram 계정 + BotFather 봇 토큰

## Port·Path Convention

| 항목 | 값 | 비고 |
|---|---|---|
| Gateway HTTP | `127.0.0.1:18789` | Control UI + API |
| Config·data dir | `~/.openclaw/` | onboarding 결과·credentials·메모리 |
| Code (npm install 결과) | `~/.nvm/versions/node/v<ver>/bin/openclaw` | nvm 사용 시 |
| systemd-user service | `openclaw-gateway.service` | `systemctl --user` 로 관리 |

---

## 셋업 순서

### Step 1 — Node.js 24 준비

기존 환경 확인:
```bash
node --version
```

24.x 또는 22.14+ 가 보이면 통과. 아니면 nvm 으로 설치:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
exec bash
nvm install 24
nvm use 24
nvm alias default 24
```

**검증**:
```bash
node --version    # v24.x.x 출력 기대
which npm         # nvm 경로 안에 있는지
```

### Step 2 — OpenClaw 설치

공식 install.sh 의 **npm method** (시스템 Node 사용, 가장 단순):
```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

`--no-onboard` 로 설치만 하고 onboarding 은 다음 단계에서 명시적으로. CI 친화적 + 단계별 검증 가능.

**검증**:
```bash
which openclaw                  # /home/$USER/.nvm/versions/node/v24.x.x/bin/openclaw 기대
openclaw --version              # OpenClaw 2026.x.x (commit hash) 형태
```

### Step 3 — Onboarding (provider key + 게이트웨이 설정)

```bash
openclaw onboard --install-daemon
```

대화형 마법사:
- 모델 provider 선택 (Anthropic 권장 — 2nd-brain 시스템과 일관)
- API key 입력 (입력 후 `~/.openclaw/agents/<id>/agent/auth-profiles.json` 에 저장)
- gateway token 자동 생성 → `~/.openclaw/.env`
- `--install-daemon` 으로 systemd-user service `openclaw-gateway.service` 등록 + start

**검증**:
```bash
ls ~/.openclaw/openclaw.json                              # 메인 설정 생성
systemctl --user list-unit-files | grep openclaw          # openclaw-gateway.service 등장
systemctl --user is-active openclaw-gateway.service       # active
```

### Step 4 — 게이트웨이 헬스체크

게이트웨이 상태 + 네트워크 도달성:
```bash
openclaw gateway status
```

HTTP probe (auth 불필요):
```bash
curl -fsS http://127.0.0.1:18789/healthz && echo "  liveness OK"
curl -fsS http://127.0.0.1:18789/readyz  && echo "  readiness OK"
```

깊이 있는 종합 진단:
```bash
openclaw doctor --non-interactive
```

**검증 요점**:
- `gateway status` 의 listening port = 18789
- `/healthz` HTTP 200
- `/readyz` HTTP 200
- doctor 출력에 critical 없음 (warning 은 허용)

### Step 5 — Control UI 확인 (선택)

브라우저로 dashboard 열기:
```bash
openclaw dashboard
```

WSL2 에서 호스트 Windows 브라우저로 열고 싶으면 URL 만 출력:
```bash
openclaw dashboard --no-open
# 출력 URL 을 Windows 브라우저 주소창에 붙여넣기
```

dashboard 가 정상 로드되고 settings 진입 가능하면 통과.

### Step 6 — Telegram 채널 페어링

#### 6a. BotFather 로 봇 생성
1. Telegram 에서 **@BotFather** 와 대화 (handle 정확히 `@BotFather` 인지 확인 — fake 봇 주의)
2. `/newbot` → 안내대로 봇 이름·username 결정
3. 출력되는 token (`123456:ABC-DEF-GHI...`) 복사 보관

#### 6b. 게이트웨이에 token + DM 정책 등록

```bash
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.botToken "123456:ABC-DEF-GHI..."
openclaw config set channels.telegram.dmPolicy "pairing"
```

`dmPolicy` 값:
- `pairing` (권장 default) — 첫 메시지 시 페어링 코드로 승인
- `allowlist` — `allowFrom` 에 등록된 numeric user ID 만 허용
- `open` — 누구나 (봇이 공개일 때만)

설정 반영 위해 게이트웨이 재시작:
```bash
systemctl --user restart openclaw-gateway.service
```

**검증**:
```bash
openclaw config get channels.telegram.botToken    # 마스킹된 토큰 보임
journalctl --user -u openclaw-gateway.service -n 30 --no-pager | grep -i telegram
# "telegram channel started" 또는 폴링 시작 로그 기대
```

#### 6c. 첫 메시지로 페어링 흐름 트리거

1. Telegram 에서 본인 봇에게 메시지 한 줄 (예: `안녕`)
2. 봇이 페어링 코드로 응답 (예: "Pairing code: ABC123. Approve on host.")
3. 호스트에서 승인:

```bash
openclaw pairing list telegram                 # 대기 중 페어링 보임
openclaw pairing approve telegram <CODE>       # 봇이 응답한 코드 입력
```

> **참고**: 페어링 코드는 1시간 유효. 만료되면 다시 메시지 보내서 새 코드 받기.

**검증** (페어링 후 ~5초):
```bash
ls ~/.openclaw/credentials/telegram-pairing.json   # 페어링 결과 저장
ls ~/.openclaw/telegram/                            # 폴링 상태 디렉토리 활성
```

**End-to-end 검증**: Telegram 봇에게 평범한 질문 (예: `오늘 날씨 어때?`) → Claude 의 답변이 수 초 내 도착.

### Step 7 — 자동 시작 + 영속성

systemd-user 가 부팅·로그인 시 게이트웨이 자동 시작:
```bash
systemctl --user enable openclaw-gateway.service
loginctl enable-linger $USER       # 로그아웃 후에도 user-service 유지
```

**검증** (재로그인 또는 재부팅 후):
```bash
systemctl --user is-enabled openclaw-gateway.service     # enabled
systemctl --user is-active openclaw-gateway.service      # active
curl -fsS http://127.0.0.1:18789/healthz                 # 200
```

### Step 8 — Multi-agent 추가 (선택)

Default 셋업 후 `main` 한 에이전트만 존재. 워크스페이스·라우팅 분리가 필요한 두 번째 에이전트(예: `research`) 추가:

```bash
openclaw agents add research
```

CLI 가 자동으로:
- `~/.openclaw/agents/research/{agent,workspace}/` 생성
- `openclaw.json` 의 `agents.list[]` 에 새 항목 등록 (host home 절대경로로 `workspace`·`agentDir` 박힘 — 컨테이너 이행 시 변환 필요)
- 라우팅 바인딩 옵션 안내

**검증**:
```bash
openclaw agents list                # main + research 둘 다 보임
ls ~/.openclaw/agents/              # main/ + research/
```

### Step 9 — gog 스킬 통합 (선택, 2nd-brain 통합 패턴)

배경: brain-system 의 토폴로지는 **AI 매개 트랙(OpenClaw) 이 결정형 백엔드(`gog`) 에 위임** — Telegram 으로 들어오는 "메일 검색해줘" 같은 요청을 OpenClaw 가 받고, 실제 Gmail/Calendar/Drive API 호출은 host 의 `gog` 가 처리. 자세한 맥락: `2nd-brain-vault/knowledge/02_areas/brain-system/tools/gogcli/README.md`.

**전제**: host 에 `gog` 설치 + 인증 완료 (`docs/gogcli-container-setup.md` 참조).

스킬 디렉토리 + 메타 파일 작성:
```bash
mkdir -p ~/.openclaw/workspace/skills/gog
```

`~/.openclaw/workspace/skills/gog/SKILL.md` 작성:
```markdown
# gog skill

Use the host `gog` CLI to interact with Google Workspace (Gmail, Calendar, Drive, Docs, Sheets).

## When to use
- User asks about Gmail messages, threads, labels
- Calendar events, drafts, contacts
- Drive file search, Docs/Sheets read

## How to invoke
Run `gog <subcommand> --account <email> ...` via the Bash tool.
Common subcommands: `gmail search-threads`, `calendar events list`, `drive list`.

Never use claude.ai connectors (incomplete) — `gog` is the canonical entry.
```

`~/.openclaw/workspace/skills/gog/_meta.json`:
```json
{
  "id": "gog",
  "version": "1.0.0",
  "description": "Host-installed Google Workspace CLI bridge"
}
```

**검증**:
```bash
ls ~/.openclaw/workspace/skills/gog/        # SKILL.md, _meta.json 둘 다
openclaw skills list 2>&1 | grep -i gog     # 스킬 목록에 등장
```

End-to-end: Telegram 봇에 "오늘 받은 메일 요약해줘" 같은 요청 → OpenClaw 가 gog 스킬 호출 → host gog 가 실제 Gmail API 호출 → 응답.

> **컨테이너 이행 주의**: 이 스킬은 host 의 `gog` 바이너리를 호출. OpenClaw 를 컨테이너로 옮길 때 두 가지 선택:
> - (a) 컨테이너 안에 `gog` 함께 설치
> - (b) host gog 를 컨테이너에 bind-mount 또는 sidecar 로 노출
>
> 결정은 아래 "컨테이너 이행" 섹션 참조.

---

## 종합 검증 체크리스트 (모두 PASS = 운영 가능)

```bash
# 1. 설치 + 버전
openclaw --version

# 2. 설정 파일 존재
ls ~/.openclaw/openclaw.json

# 3. 게이트웨이 service 활성·자동시작
systemctl --user is-enabled openclaw-gateway.service
systemctl --user is-active openclaw-gateway.service

# 4. 게이트웨이 HTTP 헬스
curl -fsS http://127.0.0.1:18789/healthz && echo "  liveness OK"
curl -fsS http://127.0.0.1:18789/readyz  && echo "  readiness OK"

# 5. 종합 진단
openclaw doctor --non-interactive

# 6. Telegram 채널 (해당 시)
ls ~/.openclaw/credentials/telegram-pairing.json
openclaw config get channels.telegram.enabled

# 7. Multi-agent (Step 8 적용 시)
openclaw agents list

# 8. gog 스킬 (Step 9 적용 시)
ls ~/.openclaw/workspace/skills/gog/
```

---

## 트러블슈팅

### `openclaw` 명령을 새 터미널에서 못 찾음

원인: nvm 의 PATH 셋업이 셸 rc 에 없음 (npm install 은 됐지만 PATH 가 풀리지 않음).

조치:
```bash
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
exec bash
which openclaw   # 이제 잡혀야 함
```

### `/healthz` 가 timeout 또는 connection refused

원인: 게이트웨이 service 가 시작 안됨, 또는 다른 포트에서 listen.

조치:
```bash
journalctl --user -u openclaw-gateway.service -n 50 --no-pager
ss -tlnp | grep 18789                  # 18789 listen 중인지
systemctl --user restart openclaw-gateway.service
```

로그에 `Cannot find module ...` 류 보이면 npm install 단계로 돌아가서 재설치.

### Telegram 봇이 메시지에 응답 안함

체크 순서:
1. **토큰 정확성**: `openclaw config get channels.telegram.botToken`
2. **폴링 활성**: `journalctl --user -u openclaw-gateway.service -n 30 --no-pager | grep -i telegram`
3. **BotFather 에서 봇 활성 상태** 확인 (`/mybots` → 봇 선택 → API token 유효 여부)
4. **dmPolicy 충돌**: `pairing` 인데 페어링 안 했으면 메시지 무시됨 → Step 6c 페어링 진행
5. **대기 중 페어링**: `openclaw pairing list telegram` 확인 후 approve

### npm install 중 OOM (exit 137)

원인: 메모리 부족 (특히 `sharp`/`libvips` 빌드 중).

조치: WSL2 의 `~/.wslconfig` (Windows 측에서 편집):
```ini
[wsl2]
memory=4GB
swap=4GB
```
Windows PowerShell 에서 `wsl --shutdown` → WSL2 재시작.

### `openclaw doctor` 가 sandbox 관련 경고

대부분 무시 가능 — sandbox 는 default off. 혹은 끄기 명시:
```bash
openclaw config set agents.defaults.sandbox.mode off
```

### 설정 파일 손상 시 backup 으로 복구

`~/.openclaw/` 안에 자동 backup 회전 (`openclaw.json.bak.{1..4}` + `last-good`) 가 있음. 가장 최근 정상 설정 복구:
```bash
cp ~/.openclaw/openclaw.json.last-good ~/.openclaw/openclaw.json
systemctl --user restart openclaw-gateway.service
```

---

## 운영 사례

| 머신 | 셋업 일자 | 설치 방법 | 비고 |
|---|---|---|---|
| desktop (ai4lt-wsl2) | 2026-04-23 | install.sh npm method, nvm Node 24 | 첫 적용. Telegram 페어링 완료, 운영 테스트 중 |

새 머신 추가 시 본 표 갱신.

---

## 컨테이너 이행 — 무엇이 바뀌나

향후 OpenClaw 를 Docker 모드로 이전할 때 위 native 가이드와 달라지는 점. 공식 docs (`mirror/install/docker.md`, `mirror/install/docker-vm-runtime.md`, `mirror/install/clawdock.md`) 에 근거.

### 매핑 테이블 — Native → Container

| Step | Native (현재) | Container |
|---|---|---|
| 1. Node 준비 | nvm install 24 | 이미지가 Node 번들 — 단계 없음 |
| 2. 설치 | `install.sh` (npm) | `./scripts/docker/setup.sh` (compose 기반) |
| 3. Onboarding | `openclaw onboard --install-daemon` | `docker compose run --rm --no-deps --entrypoint node openclaw-gateway dist/index.js onboard --mode local --no-install-daemon` |
| 4. 헬스체크 | `openclaw gateway status`, `curl /healthz` | `docker compose run --rm openclaw-cli gateway status` + 동일 `curl /healthz` (포트 publish 필요) |
| 5. Dashboard | `openclaw dashboard` | `docker compose run --rm openclaw-cli dashboard --no-open` |
| 6b. Telegram config | `openclaw config set channels.telegram.botToken ...` | `docker compose run --rm openclaw-cli config set ...` |
| 7. 자동시작 | systemd-user enable + linger | compose 의 `restart: unless-stopped` (Docker daemon 자동 시작 + restart policy) |
| 8. agents add | `openclaw agents add research` | `docker compose run --rm openclaw-cli agents add research` |
| 9. gog 스킬 | host 가 직접 실행 (`/usr/local/bin/gog`) | host gog 마운트 또는 컨테이너 내 설치 (Step 9 주의 박스 참조) |

### 영속성 모델 (`docker-vm-runtime.md` 발췌)

| Component | Location (in container) | 메커니즘 |
|---|---|---|
| 설정·.env | `/home/node/.openclaw/openclaw.json`, `.env` | host bind mount (host `~/.openclaw/`) |
| Auth profiles | `/home/node/.openclaw/agents/<id>/agent/auth-profiles.json` | host bind mount |
| Agent workspace | `/home/node/.openclaw/workspace/` | host bind mount |
| Credentials (telegram-pairing 등) | `/home/node/.openclaw/credentials/` | host bind mount |
| **Plugin runtime deps** | `/var/lib/openclaw/plugin-runtime-deps/` | **Docker named volume** (high-churn → bind 밖) |
| Node runtime, OS, openclaw 코드 | container fs | Docker 이미지 |
| 컨테이너 자체 | ephemeral | 안전하게 destroy 가능 |

**핵심 원칙**: 사용자 데이터는 모두 host bind mount, 생성된 high-churn 의존성은 named volume — bind mount I/O 페널티 회피. native 가이드의 "모든 영속 상태가 `~/.openclaw/` 한 곳에 모임" 디자인이 그대로 컨테이너에 매핑되는 이유.

### 컨테이너 모드의 추가 고려 사항

1. **UID 1000 매칭** — 이미지의 user 는 `node` (uid 1000). bind mount 권한 정렬 필요:
   ```bash
   sudo chown -R 1000:1000 ~/.openclaw
   ```
   호스트 user 가 uid 1000 이면 자연스러운 일치.

2. **`OPENCLAW_DISABLE_BONJOUR=1`** — Docker bridge 가 mDNS 멀티캐스트 누락 → 게이트웨이 crash-loop 방지. setup.sh default.

3. **`OPENCLAW_GATEWAY_BIND=lan`** — setup.sh default. 호스트 브라우저가 `127.0.0.1:18789` 도달 가능. `loopback` 으로 두면 컨테이너 내부에서만 접근.

4. **이미지 빌트인 HEALTHCHECK** — Docker 이미지가 자체적으로 `/healthz` ping. 실패 누적 시 orchestration (compose with restart, k8s) 자동 재시작.

5. **호스트 LLM 도달성** — 컨테이너 내부 `127.0.0.1` 은 컨테이너 자신. 호스트의 LM Studio/Ollama 사용 시 `host.docker.internal` 로 접근. Anthropic 같은 cloud API 사용 시 무관.

6. **컨테이너 업데이트**:
   ```bash
   git pull
   docker compose build
   docker compose up -d
   ```

### ClawDock — `docker compose ...` shorthand 헬퍼 (선택)

```bash
mkdir -p ~/.clawdock && curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/clawdock/clawdock-helpers.sh -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.bashrc && exec bash
```

주요 명령:
- `clawdock-start` / `-stop` / `-restart` / `-status`
- `clawdock-cli <command>` — 임의의 `openclaw-cli` 명령
- `clawdock-dashboard`, `clawdock-devices`, `clawdock-approve <id>`
- `clawdock-update` (git pull + rebuild + restart)

전체 명령: `clawdock-help`. 자세한 내용: `mirror/install/clawdock.md`.

### Migration 체크리스트 (이행 시 사용)

- [ ] host `~/.openclaw/` 백업: `tar czf ~/openclaw-pre-container-$(date +%Y%m%d).tar.gz -C ~ .openclaw`
- [ ] `openclaw.json` 의 host 절대경로 (`/home/ben/.openclaw/...`) → 컨테이너 경로 (`/home/node/.openclaw/...`) 변환
- [ ] (해당 시) gog 스킬의 host 의존성 처리 결정 (bind-mount vs 컨테이너 내 설치)
- [ ] host systemd-user `openclaw-gateway.service` disable + stop
- [ ] compose.yml 작성 (또는 공식 setup.sh 산출물 사용) + `restart: unless-stopped`
- [ ] bind mount uid 정렬 (`chown -R 1000:1000 ~/.openclaw`)
- [ ] `docker compose up -d` → `/healthz`·`/readyz` 검증
- [ ] Telegram 봇 round-trip 검증 (페어링 보존 확인)
- [ ] systemd unit 파일 archive 또는 제거

---

## 관련 문서

- 도구 개요·운영 맥락: `2nd-brain-vault/knowledge/02_areas/brain-system/tools/openclaw/README.md`
- 공식 docs 오프라인 미러 (검색·grep 용): `2nd-brain-vault/knowledge/02_areas/brain-system/tools/openclaw/mirror/`
- vault 운영 규약: `2nd-brain-vault/CLAUDE.md`
- 짝 도구 (결정형 백엔드): `2nd-brain-vault/knowledge/02_areas/brain-system/tools/gogcli/README.md`
- 컨테이너 동기화 가이드: `docs/syncthing-setup.md`
