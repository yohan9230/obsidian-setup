<#
.SYNOPSIS
    옵시디언 볼트들을 이 저장소의 obsidian/ 폴더와 맞춘다.

.DESCRIPTION
    이 저장소의 obsidian/ 이 원본이다.

      sync      원본 -> 볼트들   (설정을 뿌린다)
      capture   볼트 -> 원본     (내가 개선한 걸 거둔다)
      check     대조만 하고 아무것도 바꾸지 않는다 (기본값)

    볼트마다 달라야 하는 파일은 절대 건드리지 않는다. 그 목록의 정본이
    이 파일이다 ($PerVaultFiles). 다른 문서에 목록을 복사해두지 마라 —
    한 곳만 고치면 되게 하려고 여기 모아둔 것이다.

.EXAMPLE
    .\vault.ps1 check
    .\vault.ps1 sync
    .\vault.ps1 capture -Vault "C:\어디\docs\.obsidian"
    .\vault.ps1 init -Path "C:\어디\새볼트"      (그 폴더를 새 볼트로 만든다)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('check', 'sync', 'capture', 'init')]
    [string]$Command = 'check',

    [string]$Vault,

    [string]$Path,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Source = Join-Path $Root 'obsidian'

# ============================================================================
#  제외 목록 — 여기가 정본이다. 목록이 바뀌면 이 배열만 고치면 된다.
#
#  왜 제외하나: 볼트마다 값이 "달라야" 하는 파일들이다. 통째로 복사하면
#  전 볼트가 같아져서 각 볼트의 고유성이 파괴된다.
#  (2026-07-16 실제 사고: 마스터를 손으로 복사했다가 세 볼트의 표시명이
#   전부 "개인 원드라이브"가 됐다. 커밋 직전에 발견해 되돌렸다.)
# ============================================================================
$PerVaultFiles = @(
    'workspace.json'                              # 열린 탭·창 배치. 공개 저장소엔 작업 문서 제목이 드러나서도 안 된다
    'workspace-mobile.json'                       # 위와 같음(모바일)
    'graph.json'                                  # 그래프 뷰 확대·위치
    'plugins/vault-nickname/data-shared.json'     # 볼트 표시명 ← 덮으면 볼트 스위처가 무력화된다
    'plugins/target-pane/data.json'               # 창 ID. first-run-layout 이 어차피 재생성한다
)

# ---------------------------------------------------------------------------

function Get-RelPaths {
    param([string]$RootDir)
    $out = @{}
    if (-not (Test-Path $RootDir)) { return $out }
    $prefix = (Resolve-Path $RootDir).Path.TrimEnd('\') + '\'
    Get-ChildItem $RootDir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($prefix.Length) -replace '\\', '/'
        $out[$rel] = $_.FullName
    }
    return $out
}

function Test-Excluded {
    param([string]$Rel)
    return $PerVaultFiles -contains $Rel
}

function Get-Hash {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm MD5).Hash
}

function Get-TargetVaults {
    $vaults = @()

    # C:\dev 아래 자동 탐색. 레포 이름을 코드에 박지 않는다(이 저장소는 공개다).
    Get-ChildItem 'C:\dev' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Join-Path $_.FullName 'docs\.obsidian'
        if ((Test-Path $p) -and ($_.FullName -ne $Root)) { $vaults += $p }
    }

    # C:\dev 밖의 볼트(개인 원드라이브 등)는 로컬 설정에 적는다.
    # vault.local.json 은 .gitignore 대상이라 공개되지 않는다.
    $localCfg = Join-Path $Root 'vault.local.json'
    if (Test-Path $localCfg) {
        $cfg = Get-Content $localCfg -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.extraVaults) {
            foreach ($v in $cfg.extraVaults) {
                if (Test-Path $v) { $vaults += $v }
                else { Write-Host "  [경고] 로컬 설정의 볼트를 못 찾음: $v" -ForegroundColor Yellow }
            }
        }
    }
    return $vaults
}

function Test-ObsidianRunning {
    $p = Get-Process -Name 'Obsidian' -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host ""
        Write-Host "  옵시디언이 실행 중입니다 ($($p.Count)개)." -ForegroundColor Red
        Write-Host "  지금 파일을 바꾸면 옵시디언이 도로 덮어쓸 수 있습니다. 닫고 다시 실행하세요." -ForegroundColor Red
        return $true
    }
    return $false
}

function Test-GitignoreSync {
    # .gitignore 는 git 이 리터럴만 읽으므로 이 목록과 중복이 불가피하다.
    # 중복은 남기되 "조용히 어긋나는 것"만은 막는다.
    $gi = Join-Path $Root '.gitignore'
    if (-not (Test-Path $gi)) { return }
    $lines = Get-Content $gi -Encoding UTF8 | Where-Object { $_ -match '^\s*obsidian/' } | ForEach-Object { $_.Trim() -replace '^obsidian/', '' }
    $missing = $PerVaultFiles | Where-Object { $lines -notcontains $_ }
    $extra = $lines | Where-Object { $PerVaultFiles -notcontains $_ }
    if ($missing -or $extra) {
        Write-Host ""
        Write-Host "  [경고] .gitignore 와 제외 목록이 어긋납니다" -ForegroundColor Yellow
        foreach ($m in $missing) { Write-Host "    vault.ps1 에만 있음 : $m" -ForegroundColor Yellow }
        foreach ($e in $extra) { Write-Host "    .gitignore 에만 있음 : obsidian/$e" -ForegroundColor Yellow }
        Write-Host "    -> .gitignore 를 맞춰주세요 (제외 목록의 정본은 vault.ps1 입니다)" -ForegroundColor Yellow
    }
}

function Compare-Tree {
    param([string]$From, [string]$To)
    $f = Get-RelPaths $From
    $t = Get-RelPaths $To
    $add = @(); $del = @(); $chg = @()
    foreach ($rel in $f.Keys) {
        if (Test-Excluded $rel) { continue }
        if (-not $t.ContainsKey($rel)) { $add += $rel }
        elseif ((Get-Hash $f[$rel]) -ne (Get-Hash $t[$rel])) { $chg += $rel }
    }
    foreach ($rel in $t.Keys) {
        if (Test-Excluded $rel) { continue }
        if (-not $f.ContainsKey($rel)) { $del += $rel }
    }
    return [pscustomobject]@{ Add = $add; Delete = $del; Change = $chg }
}

function Show-Plan {
    param([string]$Name, $Diff)
    $n = $Diff.Add.Count + $Diff.Delete.Count + $Diff.Change.Count
    if ($n -eq 0) {
        Write-Host ("  {0,-24} 이미 같음" -f $Name) -ForegroundColor DarkGray
        return $false
    }
    Write-Host ("  {0,-24} 추가 {1} / 삭제 {2} / 덮어씀 {3}" -f $Name, $Diff.Add.Count, $Diff.Delete.Count, $Diff.Change.Count) -ForegroundColor Cyan
    foreach ($p in $Diff.Add) { Write-Host "      + $p" -ForegroundColor Green }
    foreach ($p in $Diff.Delete) { Write-Host "      - $p" -ForegroundColor Red }
    foreach ($p in $Diff.Change) { Write-Host "      ~ $p" -ForegroundColor Yellow }
    return $true
}

function Copy-Tree {
    param([string]$From, [string]$To, $Diff)
    foreach ($rel in $Diff.Delete) {
        Remove-Item (Join-Path $To ($rel -replace '/', '\')) -Force
    }
    foreach ($rel in ($Diff.Add + $Diff.Change)) {
        $dst = Join-Path $To ($rel -replace '/', '\')
        $dir = Split-Path $dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item (Join-Path $From ($rel -replace '/', '\')) $dst -Force
    }
    # 빈 폴더 정리
    Get-ChildItem $To -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        if (-not (Get-ChildItem $_.FullName -Force)) { Remove-Item $_.FullName -Force }
    }
}

function Show-Nicknames {
    param([string[]]$Vaults)
    Write-Host ""
    Write-Host "  볼트 표시명 (서로 달라야 정상):" -ForegroundColor Cyan
    $names = @()
    foreach ($v in $Vaults) {
        $p = Join-Path $v 'plugins\vault-nickname\data-shared.json'
        $n = '(없음)'
        if (Test-Path $p) { $n = (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json).nickname }
        $names += $n
        Write-Host ("    {0,-46} -> {1}" -f $v, $n)
    }
    $dup = $names | Where-Object { $_ -ne '(없음)' } | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dup) {
        Write-Host ""
        Write-Host "  [경고] 표시명이 겹칩니다 — 볼트 스위처가 무력화됩니다:" -ForegroundColor Red
        foreach ($d in $dup) { Write-Host "    '$($d.Name)' x $($d.Count)" -ForegroundColor Red }
    }
}

# ============================== main =======================================

if (-not (Test-Path $Source)) {
    Write-Host "원본 폴더가 없습니다: $Source" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "원본: $Source" -ForegroundColor White
Test-GitignoreSync

if ($Command -eq 'init') {
    if (-not $Path) {
        Write-Host ""
        Write-Host "init 은 -Path 로 새 볼트를 만들 폴더를 지정해야 합니다." -ForegroundColor Red
        Write-Host '예: .\vault.ps1 init -Path "C:\어디\새볼트"' -ForegroundColor DarkGray
        exit 1
    }
    $dotObs = Join-Path $Path '.obsidian'
    if ((Test-Path $dotObs) -and -not $Force) {
        Write-Host ""
        Write-Host "이미 볼트가 있습니다: $dotObs" -ForegroundColor Red
        Write-Host "덮어쓰려면 -Force (기존 설정이 사라집니다). 이미 있는 볼트를 맞추려면 sync 를 쓰세요." -ForegroundColor DarkGray
        exit 1
    }
    # 새 볼트는 옵시디언이 아직 모르는 폴더라, 다른 볼트가 열려 있어도 상관없다.
    # (sync 와 달리 옵시디언 실행 여부를 따지지 않는다.)

    Write-Host ""
    Write-Host "새 볼트: $Path" -ForegroundColor White
    Write-Host ""

    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

    # .obsidian 생성 — 제외 목록은 빼고 복사한다.
    # workspace/graph/target-pane 은 새 볼트가 스스로 새로 만든다.
    $src = Get-RelPaths $Source
    $nCopied = 0
    foreach ($rel in $src.Keys) {
        if (Test-Excluded $rel) { continue }
        $dst = Join-Path $dotObs ($rel -replace '/', '\')
        $dir = Split-Path $dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item $src[$rel] $dst -Force
        $nCopied++
    }

    # 표시명 = 이 폴더 이름. 볼트마다 달라야 하므로 여기서 새로 만든다.
    # 옵시디언 스타일에 맞춰 BOM 없이, 끝에 개행 없이 쓴다.
    $nick = Split-Path $Path -Leaf
    $nickDir = Join-Path $dotObs 'plugins\vault-nickname'
    if (-not (Test-Path $nickDir)) { New-Item -ItemType Directory -Path $nickDir -Force | Out-Null }
    $nickJson = "{`n  `"nickname`": `"$nick`"`n}"
    [System.IO.File]::WriteAllText((Join-Path $nickDir 'data-shared.json'), $nickJson, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host "  .obsidian 생성 ($nCopied 개 파일, 표시명: $nick)" -ForegroundColor Green

    # 환경 문서 — 이미 있으면 안 건드린다(같은 이름이면 요한 것을 지키고 생략).
    # 목록.md 는 왼쪽 탭, Obsidian-단축키.md 는 오른쪽 탭으로 열린다(first-run-layout).
    foreach ($doc in @('목록.md', 'Obsidian-단축키.md', '문서-링크-규칙.md')) {
        $s = Join-Path $Root $doc
        $d = Join-Path $Path $doc
        if ((Test-Path $s) -and -not (Test-Path $d)) { Copy-Item $s $d; Write-Host "  문서 추가: $doc" -ForegroundColor Green }
    }

    # 앞으로 sync/check 대상에 포함되도록 등록.
    # C:\dev\<레포>\docs\.obsidian 는 자동 탐색되지만, 그 밖이면 등록해야 안 뒤처진다.
    $resolved = (Resolve-Path $dotObs).Path
    if ((Get-TargetVaults) -notcontains $resolved) {
        $localCfg = Join-Path $Root 'vault.local.json'
        if (Test-Path $localCfg) { $cfg = Get-Content $localCfg -Raw -Encoding UTF8 | ConvertFrom-Json }
        else { $cfg = [pscustomobject]@{ extraVaults = @() } }
        $cfg.extraVaults = @(@($cfg.extraVaults) + $resolved | Where-Object { $_ } | Select-Object -Unique)
        $cfg | ConvertTo-Json | Set-Content $localCfg -Encoding UTF8
        Write-Host "  vault.local.json 에 등록 — 앞으로 sync 대상에 포함됩니다." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  완료. Obsidian 에서 '$Path' 를 보관함으로 열면 됩니다." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if ($Command -eq 'capture') {
    if (-not $Vault) {
        Write-Host ""
        Write-Host "capture 는 -Vault 로 거둘 볼트를 지정해야 합니다." -ForegroundColor Red
        Write-Host '예: .\vault.ps1 capture -Vault "C:\어디\docs\.obsidian"' -ForegroundColor DarkGray
        exit 1
    }
    if (-not (Test-Path $Vault)) { Write-Host "볼트를 못 찾음: $Vault" -ForegroundColor Red; exit 1 }
    # capture 는 볼트를 읽기만 하고 원본에 쓰므로 옵시디언이 켜져 있어도 된다.
    # (오히려 설정을 막 바꾼 직후에 거두는 게 자연스럽다.)

    Write-Host ""
    Write-Host "거둘 볼트: $Vault" -ForegroundColor White
    Write-Host ""
    $diff = Compare-Tree -From $Vault -To $Source
    $has = Show-Plan -Name '원본' -Diff $diff
    if (-not $has) { Write-Host ""; exit 0 }
    if (-not $Force) {
        Write-Host ""
        $ans = Read-Host "  원본을 이 볼트 기준으로 갱신할까요? (y/N)"
        if ($ans -ne 'y') { Write-Host "  취소했습니다."; exit 0 }
    }
    Copy-Tree -From $Vault -To $Source -Diff $diff
    Write-Host ""
    Write-Host "  완료. git diff 로 확인하고 커밋하세요." -ForegroundColor Green
    Write-Host ""
    exit 0
}

$targets = Get-TargetVaults
if ($targets.Count -eq 0) {
    Write-Host ""
    Write-Host "맞출 볼트를 못 찾았습니다." -ForegroundColor Yellow
    Write-Host "C:\dev\<레포>\docs\.obsidian 가 없고, vault.local.json 도 비어 있습니다." -ForegroundColor DarkGray
    exit 0
}

Write-Host ""
Write-Host "대상 볼트 $($targets.Count) 곳:" -ForegroundColor White
Write-Host ""

$plans = @()
$any = $false
foreach ($v in $targets) {
    $diff = Compare-Tree -From $Source -To $v
    $name = Split-Path (Split-Path $v -Parent) -Parent | Split-Path -Leaf
    if (Show-Plan -Name $name -Diff $diff) { $any = $true }
    $plans += [pscustomobject]@{ Vault = $v; Diff = $diff }
}

Write-Host ""
Write-Host "  건드리지 않는 파일 (볼트마다 달라야 함):" -ForegroundColor DarkGray
foreach ($f in $PerVaultFiles) { Write-Host "      $f" -ForegroundColor DarkGray }

if ($Command -eq 'check') {
    Show-Nicknames -Vaults $targets
    Write-Host ""
    Write-Host "  (check 모드 — 아무것도 바꾸지 않았습니다. 적용하려면 sync)" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

if (-not $any) {
    Write-Host ""
    Write-Host "  전부 이미 같습니다. 할 일이 없습니다." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if (Test-ObsidianRunning) { exit 1 }

if (-not $Force) {
    Write-Host ""
    $ans = Read-Host "  진행할까요? (y/N)"
    if ($ans -ne 'y') { Write-Host "  취소했습니다."; exit 0 }
}

Write-Host ""
foreach ($p in $plans) {
    Copy-Tree -From $Source -To $p.Vault -Diff $p.Diff
    Write-Host "  완료: $($p.Vault)" -ForegroundColor Green
}

Show-Nicknames -Vaults $targets
Write-Host ""
