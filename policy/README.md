# managed-settings.json — 컨테이너 Claude 강제 정책

이 디렉토리의 `managed-settings.json` 은 컨테이너 Claude Code 에 RO bind mount 되어 (`/etc/claude-code/managed-settings.json`) **사용자가 override 할 수 없는 강제 정책**으로 작동한다.

## 의도

Prompt injection 공격에 대한 1차 방어 layer. 외부에서 가져온 데이터 (메일·웹·논문 PDF·sources 노트) 안에 숨은 명령어가 Claude 를 통해 실행되더라도, **사고 표면을 제한된 동작에 가둔다**.

직접적 배경: 2026-05 egress whitelist (squid) 제거 후 외부망 직결로 변경되어 데이터 exfiltration 차단 능력이 약화. 그 일부를 permission 정책으로 회복한다 (`memory/decision_egress_removed.md` 참조).

## 정책 그룹

### 자격증명·secret 보호 (Read/Edit/Write 차단)

| 경로 | 보호 대상 |
|---|---|
| `./.env`, `./.env.*`, `./secrets/**` | 프로젝트 자격증명 |
| `/home/user/.claude.json` | 컨테이너 OAuth state |
| `/home/user/.ssh/**`, `.aws/**`, `.gnupg/**` | 시스템 자격증명 |
| `/home/user/.config/**/credentials*` | 일반 credentials 파일 |

대응 Bash 차단: `env`, `printenv*`, `cat *.env*`, `cat *secret*`, `cat *credential*`, `cat /etc/shadow*`.

### 외부 데이터 송신 차단 (egress 제거 보완 — 핵심 layer)

`curl`, `wget`, `nc`, `netcat`, `ncat`, `ssh`, `scp`, `sftp`, `rsync *@*`, `rsync *::*` — prompt injection 으로 vault 데이터를 외부로 빼내는 가장 흔한 통로 모두 차단.

> 참고: Claude Code 의 `WebFetch` 도구는 Bash 와 별개 layer 라 영향 없음. 일반적 외부 정보 fetch 는 그쪽으로 가능.

### 파괴적 명령

`rm -rf /*`, `rm -rf ~`, `rm -rf ~/*`, `rm -rf $HOME*`, `dd if=*`, `mkfs*`, `shred *`.

### 권한 상승

`sudo *`, `su *`, `setuid*`, `setcap*`, `chmod 777 *`, `chmod -R 777*`.

> 참고: 컨테이너의 `cap_drop: ALL` + non-root 로 이미 OS 차원에서도 차단되지만, 명령 실행 자체를 막아 prompt injection 시도 자체를 봉쇄.

### Git 위험

`git push --force*`, `git push -f *` (강제 푸시), `git reset --hard*` (작업 손실), `git clean -fd*` (untracked 강제 삭제).

### MCP destructive

`mcp__*__send*`, `mcp__*__delete*`, `mcp__*__remove*`, `mcp__*__trash*` — 모든 MCP 서버의 발송·삭제·휴지통 도구 차단. Gmail 무단 발송, Drive 파일 삭제, Calendar 이벤트 삭제 등 destructive 작업이 prompt injection 으로 트리거되는 시나리오 봉쇄.

## 한계 — 반드시 알아둘 것

glob 매칭은 다음 우회에 취약:

| 우회 기법 | 예시 |
|---|---|
| variable expansion | `URL="curl ..."; $URL` |
| command substitution | `$(echo curl ...)` |
| quote escaping | `c""url ...` |
| piping | `echo "curl ..." \| bash` |

robust 한 차단은 **PreToolUse hook** 으로 명령 정규화 후 매칭해야 가능. 이 정책은 모델의 실수·일상적 prompt injection 시도를 막는 **1차 방어**이며, 의도적 우회는 별도 layer 가 필요.

후속 보강 (별도 작업):
- vault 저장소 (`~/projects/2nd-brain-vault/.claude/settings.json`) 에 사용자 점진적 `ask`/`allow` 정책
- `bash-guard` 류 PreToolUse hook 으로 우회 방지

## 평가 순서

Claude Code 의 permission 평가: **deny → ask → allow**. deny 매칭이 우선이라 다른 layer 로 override 불가능. 그래서 이 파일에는 *정말 절대 차단해야 할 것* 만 둠. 일상 협업의 `ask`/`allow` 는 user/project 정책에서 사용자가 학습.

## 변경 절차

이 파일은 RO bind mount — 컨테이너 재빌드 없이 호스트에서 편집 후 재기동만 하면 즉시 반영:

```bash
$EDITOR policy/managed-settings.json
make restart
```

JSON 문법 검증:

```bash
jq . policy/managed-settings.json > /dev/null && echo OK
```

`minimumVersion` 은 `.env` 의 `CLAUDE_CODE_VERSION` 과 정렬되도록 함께 갱신.
