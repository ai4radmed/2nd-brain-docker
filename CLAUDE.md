# 2nd-brain-docker — 실행환경 구축 자동화

`2nd-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산 저장소.

## 짝 프로젝트와의 관계

이 저장소는 **실행환경 구축 자동화**만 담당한다. 운영 방법론과 실제 데이터는 별도 짝 저장소에 있다.

| 저장소 | 역할 | 위치 | 공개 |
|---|---|---|---|
| **2nd-brain-docker** (이곳) | Docker 이미지·compose·Makefile — 컨테이너로 실행환경을 빌드·기동 | GitHub `ai4radmed/2nd-brain-docker`, 로컬 `~/projects/2nd-brain-docker/` | 공개 |
| **2nd-brain-guide** (짝) | PARA 운영 방법론·템플릿·빈 vault 골격 — 외부인이 자기 시스템 부트스트랩에 사용 | GitHub `ai4radmed/2nd-brain-guide` (예정), 로컬 `~/projects/2nd-brain-guide/` | 공개 |
| **2nd-brain** (짝, vault) | knowledge·sources 데이터, brainify 결과물 — Ben 본인의 정본 | 로컬 `~/projects/2nd-brain/` (WSL2 ext4 native) · Windows에선 `\\wsl.localhost\Ubuntu\home\ben\projects\2nd-brain\` · Syncthing 동기 | 비공개 |

비유:

- **docker** = 건물(실행환경)을 짓는 도면
- **guide** = 건물 안에서의 생활 규칙·가구 배치도 (외부인도 따라할 수 있도록 일반화된 형태)
- **2nd-brain** = 그 건물에서 실제로 살아가는 한 사람의 살림살이

## 권위 문서 — 영역별 정본

권위가 한 곳에 있지 않고 영역별로 나뉜다.

| 영역 | 정본 위치 |
|---|---|
| 데이터 운영 규약 (PARA, companion note, 파일명, 동기화 규칙) | `~/projects/2nd-brain/CLAUDE.md` |
| 공개 방법론 (외부인 onboarding, vault 골격, 일반화된 워크플로우) | `~/projects/2nd-brain-guide/CLAUDE.md` 및 `2nd-brain-guide/README.md` |
| 실행환경 자산 (마운트 경로, UID 매핑, compose 패턴) | 이 저장소 (자기참조) |

이 저장소(Dockerfile·compose.yml·Makefile·entrypoint)에서 마운트 경로·user 매핑·작업 디렉토리 등을 변경할 경우 **반드시 `2nd-brain/CLAUDE.md` 의 Docker 운영 규칙과 동기화**할 것. 두 곳이 어긋나면 컨테이너 안에서 경로 번역이 깨진다.

## 운영 흐름

1. 이 저장소에서 `make build` → 이미지 빌드
2. `make rw` / `make ro` → 컨테이너 기동, 호스트 `~/projects/2nd-brain` 을 컨테이너 `/workspace/2nd-brain` 으로 마운트
3. 컨테이너 안에서 Claude CLI 가 2nd-brain 프로젝트(`/workspace/2nd-brain/CLAUDE.md`) 를 인식하고 작업
4. 컨테이너 안의 모든 작업 규약은 그 CLAUDE.md 를 따름

상세 사용법은 `README.md` 참조.
