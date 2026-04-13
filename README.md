# caddy

이 프로젝트는 `my-rag-mcp`, `open-webui` 어느 쪽에도 속하지 않는 별도 `Caddy` 프로젝트다.
역할은 공개 호스트에 대한 공용 HTTPS 진입점을 제공하고, 요청 경로 기준 reverse proxy를 처리하는 것이다.

## 운영 핵심

### 필수 환경변수

이 폴더에는 개인 도메인이나 개인 식별값을 추적 파일로 저장하지 않는다.
실제 값은 `env.local.ps1`에 입력하고, 이 파일은 Git에서 제외한다.

```powershell
$env:CADDY_PUBLIC_HOST = "your-public-host.example.com"
$env:OPEN_WEBUI_PUBLIC_HOST = "your-open-webui-host.example.com"
$env:MYRAG_UPSTREAM = "127.0.0.1:18444"
$env:OPEN_WEBUI_UPSTREAM = "127.0.0.1:18445"
```

### Windows 서비스 등록

`bin\nssm.exe`를 준비한 뒤 관리자 권한 PowerShell에서 아래 스크립트로 서비스를 등록한다.

```powershell
.\ops\register_windows_services.ps1
```

등록 후 서비스 이름은 `CaddyGateway`다.

상태 확인 예시:

```powershell
Get-Service CaddyGateway
```

### 설정 변경 반영

`Caddyfile` 수정 후 설정 반영 방법은 서비스 재시작이다.

```powershell
Restart-Service CaddyGateway
```

### 로그 관리

로그는 `NSSM`이 직접 파일로 기록하고 회전한다.

- 표준 출력: `logs\CaddyGateway.out.log`
- 표준 에러: `logs\CaddyGateway.err.log`
- 회전 기준 용량: `1MB`

로그 회전 설정은 `ops\register_windows_services.ps1`에서 서비스 등록 시 함께 적용된다.

## 책임 범위

- 공개 호스트 `:443` 수신
- TLS/인증서 관리
- 경로 기준 reverse proxy
- 공용 진입점 관리

## 책임 범위 아님

- `my-rag-mcp` 실행 또는 내부 로직 관리
- `open-webui` 실행 또는 내부 로직 관리
- 각 앱 프로젝트 내부 파일 수정
- 앱 프로젝트 안에 라우팅 규칙 추가

## 라우팅 규칙

현재 `Caddyfile` 기준 라우팅은 아래와 같다.

- `/myrag` -> `127.0.0.1:18444`
- `OPEN_WEBUI_PUBLIC_HOST` -> `127.0.0.1:18445`

예시:

- `https://your-public-host.example.com/myrag`
- `https://your-open-webui-host.example.com`

## 운영 원칙

- 각 앱은 자기 포트에서만 실행한다.
- 외부 도메인, HTTPS, 경로 분기는 이 프로젝트에서만 관리한다.
- 특정 앱 프로젝트 안에 다른 앱용 라우팅 규칙을 넣지 않는다.
- 프로젝트 간 종속성이 생기지 않도록 유지한다.

## 확인 포인트

- Open WebUI 서브도메인에서 정적 자산이 정상 동작하는지 확인한다.
- 필요 시 upstream 앱이 프록시 환경을 올바르게 인식하는지 점검한다.

## 실행 방법

PowerShell에서 직접 실행:

```powershell
.\run_caddy.ps1
```

## 관련 파일

- `Caddyfile`: 공용 HTTPS 진입점 및 경로 분기 설정
- `env_loader.ps1`: 공용 환경 로더
- `env.local.ps1`: 비공개 실제 값 파일
- `env.example.ps1`: 비공개 실제 값 예시 파일
- `run_caddy.ps1`: Caddy 실행 스크립트
- `ops/register_windows_services.ps1`: NSSM 기반 Windows 서비스 등록 스크립트
