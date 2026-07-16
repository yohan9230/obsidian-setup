# obsidian-setup

요한이 쓰는 Obsidian 편집 환경 원본. 설정·플러그인·테마·스니펫·단축키가 통째로 들어있다.

**받아서 그대로 쓰면 된다.** 플러그인을 하나씩 찾아 깔 필요 없다.

## 설치

1. 이 저장소를 받는다 (`git clone` 또는 ZIP 다운로드)
2. `obsidian/` 폴더를 **볼트 폴더 안에 `.obsidian` 이라는 이름으로** 복사한다

```
내볼트/
└── .obsidian/       ← 여기에 obsidian/ 의 내용을 넣는다
```

3. Obsidian 을 재시작한다

> ⚠️ **이미 쓰던 `.obsidian` 이 있다면 먼저 백업해라.** 이 설치는 기존 설정을 덮어쓴다.
> 폴더 이름이 `obsidian` 인 이유: 점(`.`)으로 시작하면 대부분의 도구가 숨김 처리해서 다루기 번거롭고, 이 저장소 자체가 볼트로 오인되기 때문이다.

## 뭐가 들었나

- **테마** Obsidianotion
- **CSS 스니펫 6개** — 본문 너비, 목차 스타일, 할 일 취소선 제거, 뷰 헤더 숨김, 상태바 숨김, 콜아웃 가독성
- **커스텀 단축키** — `Alt+V` 볼트 전환 등
- **플러그인 14개** (아래)

## 플러그인

### 직접 만든 것 (스토어에 없음, 이 저장소에만 있음)

| 플러그인 | 하는 일 |
|---|---|
| **Vault Switcher Nicknames** | 볼트 전환 팝업(`Alt+V`)에 폴더명 대신 별명을 띄운다. 별명은 각 볼트의 `plugins/vault-nickname/data-shared.json` 에서 읽는다 |
| **First Run Layout** | 볼트를 처음 열 때 화면 배치를 잡아준다 |

### 커뮤니티 플러그인

전부 각 제작자의 저작물이며 편의를 위해 함께 넣어두었다. 출처는 아래와 같다.

| 플러그인 | 버전 | 만든 사람 |
|---|---|---|
| [Dragger](https://github.com/Ariestar) | 1.3.4 | Ariestar |
| [Fast Text Color](https://github.com/Superschnizel) | 1.1.11 | Leon Holtmeier |
| [In Progress Checkbox](https://github.com/Jyuukun) | 1.0.0 | Jyuukun |
| [List Cycler](https://www.landonschropp.com) | 1.1.1 | Landon Schropp |
| [Material Icons](https://github.com/Gust4v0Di4sC) | 1.0.1 | Gustavo Dias |
| [Style Settings](https://github.com/mgmeyers/obsidian-style-settings) | 1.0.9 | mgmeyers |
| [Open In New Tab](https://patricklee.nyc) | 1.0.9 | Patrick Lee |
| [Quick Emoji](https://alecsibilia.com) | 1.3.0 | Alec Sibilia |
| [Slash Commander](https://github.com/alephpiece) | 0.4.0 | alephpiece |
| [Target Pane](https://github.com/mjsharkey) | 0.1.2 | Michael Sharkey |
| [Vault Nickname](https://github.com/rscopic) | 1.1.12 | @rscopic |
| [VSCode Editor](https://github.com/sunxvming) | 1.0.5 | sunxvming |

테마 [Obsidianotion](https://diegoeis.com) — Diego Eis

> ⚠️ **`community-plugins.json` 의 배열 순서는 로드 순서라 기능에 영향을 준다.**
> 특히 **`open-in-new-tab` 이 `target-pane` 보다 위**에 있어야 한다. 순서가 바뀌면 Open In New Tab 이 조용히 무력화된다.

## 안 들어있는 것

볼트마다 **달라야 하는** 파일 몇 개는 일부러 뺐다. 열린 탭 배치, 볼트 별명, 창 ID 같은 것들이다. 없어도 Obsidian 이 알아서 새로 만든다.

**정확한 목록은 [`vault.ps1`](vault.ps1) 의 `$PerVaultFiles` 에 있다.** 여기 옮겨 적지 않는 이유는 두 곳에 두면 언젠가 어긋나기 때문이다. 그 파일이 정본이다.

그중 `workspace.json` 만은 성격이 다르다. 최근 연 파일 목록이라 **실제 작업한 문서 제목이 들어있어서**, 볼트별로 달라야 해서가 아니라 **공개하면 안 되기 때문에** 뺐다.

설치 후 볼트 별명을 쓰려면 `plugins/vault-nickname/data-shared.json` 을 만들고 이렇게 적으면 된다.

```json
{ "nickname": "내 볼트 이름" }
```

## 볼트를 여러 개 쓴다면

`vault.ps1` 로 여러 볼트를 이 저장소와 맞출 수 있다.

```powershell
.\vault.ps1 check     # 뭐가 다른지만 본다. 아무것도 안 바꾼다
.\vault.ps1 sync      # 이 저장소 -> 볼트들
.\vault.ps1 capture -Vault "<볼트경로>"   # 볼트에서 바꾼 걸 이 저장소로
```

`C:\dev\<폴더>\docs\.obsidian` 는 자동으로 찾는다. 그 밖의 볼트는 `vault.local.json` 에 적는다.

```json
{ "extraVaults": ["D:\\어디\\내볼트\\.obsidian"] }
```

> ⚠️ `sync` 전에 Obsidian 을 닫아라. 켜져 있으면 Obsidian 이 도로 덮어쓴다. (스크립트가 막아준다.)

## 라이선스

직접 만든 플러그인 2개와 CSS 스니펫은 자유롭게 가져다 써도 된다.
커뮤니티 플러그인과 테마는 각 제작자에게 저작권이 있으며 위 표에 출처를 밝혔다.
