# second-brain-docker

`second-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산. Claude CLI 등을 컨테이너로 띄워 호스트 파일시스템 접근을 마운트된 폴더로 한정한다.

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

- **마운트 최소화**: `/mnt/d/Gdrive/second-brain` 만 컨테이너에 노출. 호스트 `~/`·`/mnt/c`·`/etc` 등 비가시.
- **non-root**: `--user $(id -u):$(id -g)` 매핑.
- **cap_drop ALL** + **no-new-privileges** + **read-only root FS** (tmpfs `/tmp`, `/run` 만 쓰기 가능).
- **자원 제한**: mem 4G, CPU 2.

Docker 가 막지 못하는 잔여 리스크 (네트워크 egress 통한 데이터 유출 등) 는 별도 대응 필요. CLAUDE.md "경로 참조" 섹션의 Docker 운영 규칙 참조.

## 데이터 경로

| 위치 | 경로 |
|---|---|
| 호스트 (.env `SB_DATA`) | `/mnt/d/Gdrive/second-brain` |
| 컨테이너 내부 (고정) | `/workspace/second-brain` |

second-brain CLAUDE.md 의 경로 번역 테이블과 일치시킬 것.
