# 2nd-brain-docker — 실행환경 구축 자동화

`second-brain` 시스템을 격리 실행하기 위한 Docker 운영 자산 저장소.

## 짝 프로젝트와의 관계

이 저장소는 **실행환경 구축 자동화**만 담당한다. 실제 second-brain 콘텐츠·워크플로우·운영 규약은 별도 짝 프로젝트에 있다.

| 저장소 | 역할 | 위치 |
|---|---|---|
| **2nd-brain-docker** (이곳) | Docker 이미지·compose·Makefile — 컨테이너로 실행환경을 빌드·기동 | `~/projects/2nd-brain-docker/` (WSL2) |
| **second-brain** (짝) | knowledge 볼트, sources 원본, PARA 구조, 브레인화 워크플로우 — 구축된 환경 안에서의 실제 운영 | `/mnt/d/Gdrive/second-brain/` (WSL2) · `D:\Gdrive\second-brain\` (Windows) |

비유: 이 저장소는 **건물(실행환경)을 짓는 도면**, 짝 저장소는 **그 건물 안에서의 생활 규칙**.

## 권위 문서

**`second-brain/CLAUDE.md` 가 권위 있는 원본**이다. 다음 항목은 모두 그쪽이 정본이며, 이 저장소는 그것을 구현하는 측:

- 경로 번역 테이블 (Windows / WSL2 native / Docker 컨테이너)
- Docker 운영 규칙 (마운트 지점 `/workspace/second-brain` 고정, UID 매핑, compose 패턴)
- 컨테이너 안에서의 second-brain 운영 규약 전부

이 저장소(Dockerfile·compose.yml·Makefile·entrypoint)에서 마운트 경로·user 매핑·작업 디렉토리 등을 변경할 경우 **반드시 `second-brain/CLAUDE.md` 의 Docker 운영 규칙과 동기화**할 것. 두 곳이 어긋나면 컨테이너 안에서 경로 번역이 깨진다.

## 운영 흐름

1. 이 저장소에서 `make build` → 이미지 빌드
2. `make rw` / `make ro` → 컨테이너 기동, 호스트 `/mnt/d/Gdrive/second-brain` 을 컨테이너 `/workspace/second-brain` 으로 마운트
3. 컨테이너 안에서 Claude CLI 가 second-brain 프로젝트(`/workspace/second-brain/CLAUDE.md`) 를 인식하고 작업
4. 컨테이너 안의 모든 작업 규약은 그 CLAUDE.md 를 따름

상세 사용법은 `README.md` 참조.
