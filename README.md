# 2nd-brain-docker

`2nd-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산. Claude CLI 등을 컨테이너로 띄워 호스트 파일시스템 접근을 마운트된 폴더로 한정한다.

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
├── compose.yml              # 서비스 정의 (claude / claude-ro)
├── images/claude-cli/       # Claude CLI 이미지 빌드
│   ├── Dockerfile
│   └── entrypoint.sh
├── secrets/                 # API 키·토큰 (gitignored)
├── .env.example             # 환경변수 템플릿
├── .gitignore
├── .dockerignore
└── Makefile                 # `make rw`, `make ro` 단축
```

## 첫 셋업

```bash
cp .env.example .env
# .env 편집 — UID/GID/SB_DATA 확인 ($(id -u), $(id -g))

make build
```

## 사용

```bash
make rw         # 데이터 RW 컨테이너 (편집 가능, brainify 가능)
make ro         # 데이터 RO 컨테이너 (탐색·검색 전용, 변경 불가)
make shell      # 실행 중인 컨테이너에 bash 접속
make down       # 컨테이너 정리
```

평소 작업은 `make ro` 권장. 노트 편집·brainify 가 필요할 때만 `make rw`.

## 인증

기본은 OAuth (`claude login`). 첫 실행 시 컨테이너 안에서 한 번 로그인하면 `claude-state` named volume 에 영속된다 (RW/RO 컨테이너가 같은 volume 공유).

API 키 방식은 `secrets/README.md` 참조.

## 보안 모델

- **마운트 최소화**: `~/projects/2nd-brain-vault` (RW) 와 `~/projects/2nd-brain-vault-guide` (RO) 만 컨테이너에 노출. 호스트 `~/`·`/mnt/c`·`/mnt/d`·`/etc` 등 비가시.
- **non-root**: `--user $(id -u):$(id -g)` 매핑.
- **cap_drop ALL** + **no-new-privileges** + **read-only root FS** (tmpfs `/tmp`, `/run` 만 쓰기 가능).
- **자원 제한**: mem 4G, CPU 2.

Docker 가 막지 못하는 잔여 리스크 (네트워크 egress 통한 데이터 유출 등) 는 별도 대응 필요. CLAUDE.md "경로 참조" 섹션의 Docker 운영 규칙 참조.

## 데이터 경로

호스트와 컨테이너가 **동일 상대 경로** (`~/projects/...`) 를 사용합니다 — `~` 가 호스트(`/home/ben`) 와 컨테이너(`/home/user`) 각자의 home 으로 풀리므로, vault CLAUDE.md 의 import 가 **컨테이너 안 / WSL2 native 양쪽에서 동일하게 작동**합니다.

| 항목 | 경로 (호스트·컨테이너 공통) | 마운트 모드 |
|---|---|---|
| vault (.env `SB_DATA`) | `~/projects/2nd-brain-vault` (WSL2 ext4 native, Syncthing 동기) | `make rw` 시 RW, `make ro` 시 RO |
| guide (.env `SB_GUIDE`) | `~/projects/2nd-brain-vault-guide` (git 관리, 공개) | 항상 RO |

vault 의 `CLAUDE.md` 는 guide 문서들을 `@~/projects/2nd-brain-vault-guide/...` 로 `@`-import 하는 *얇은 layer* 패턴으로 운영합니다. 절대 경로(`/home/ben/...` 또는 `/home/user/...`) 를 직접 박아두지 말고 항상 `~/...` 표기를 사용해야 두 환경에서 동일하게 작동합니다.
