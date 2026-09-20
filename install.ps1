<#
install.ps1 — put `remi-hook.exe` on this Windows machine and configure a harness to call it.

This is the Windows half of the download path; `install.sh` is the POSIX one, and on both the
configuration half is `remi-hook setup`, which always runs *on* the machine it configures.
Nothing here reaches into a settings file.

PowerShell blocks a downloaded script under the default execution policy, so the usual form
builds it in memory instead of saving it — and unlike `irm | iex`, it can be passed arguments:

  & ([scriptblock]::Create((Invoke-RestMethod `
      https://github.com/un-lock-able/remi-desktop/releases/latest/download/install.ps1))) `
      --harness codex --check

Every argument is forwarded verbatim to `remi-hook setup`, so this script never has to learn
what that command's flags mean. `--harness` is one of them and has no default here either:
which agent a machine runs is the one thing an installer must not guess.

Environment:
  REMI_VERSION   release tag to install (default: the latest release)
  REMI_HOOK_BIN  path to a locally built remi-hook.exe to install instead of downloading
  REMI_REPO      owner/name on GitHub, if you forked it
  REMI_PREFIX    directory to install into (default: $env:USERPROFILE\.local\bin)
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say($message) { [Console]::Error.WriteLine($message) }
function Die($message) { [Console]::Error.WriteLine("install.ps1: $message"); exit 1 }

$repo = if ($env:REMI_REPO) { $env:REMI_REPO } else { 'un-lock-able/remi-desktop' }
$prefix = if ($env:REMI_PREFIX) { $env:REMI_PREFIX } else { Join-Path $env:USERPROFILE '.local\bin' }

# `remi-hook.exe`, never another name: setup recognises its own hooks by that file name, so a
# differently named copy makes `uninstall` a no-op and a second `setup` a duplicate.
$target = Join-Path $prefix 'remi-hook.exe'

# ---------------------------------------------------------------- which build do we want

# One Windows build is published, and an ARM64 machine runs it under the x64 emulation Windows
# provides — there is no arm64 asset to prefer over it. A 32-bit Windows has no build at all.
function Get-AssetName {
    # The 32-bit PowerShell that ships alongside the 64-bit one reports x86 for the process and
    # names the real architecture in the second variable.
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    switch ($arch) {
        'AMD64' { 'remi-hook-windows-x86_64.exe' }
        'ARM64' { 'remi-hook-windows-x86_64.exe' }
        default { Die "no prebuilt remi-hook for Windows $arch — build it from source with cargo" }
    }
}

# `latest/download/<asset>` is GitHub's own alias and saves an API call, which also keeps this
# script working against a rate-limited or unauthenticated network.
function Get-ReleaseUrl($asset) {
    if ($env:REMI_VERSION) {
        "https://github.com/$repo/releases/download/$env:REMI_VERSION/$asset"
    } else {
        "https://github.com/$repo/releases/latest/download/$asset"
    }
}

# ---------------------------------------------------------------- fetching and verifying

function Save-File($url, $destination) {
    # Windows PowerShell 5.1 still defaults to a TLS version GitHub stopped accepting, and its
    # progress bar costs more time on a small file than the transfer does.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
}

# A one-line install that skips verification is asking the user to trust the network as well as
# the publisher. This one refuses to install a binary whose hash is not in the release's
# SHASUMS256.txt, rather than warning and continuing.
function Assert-Checksum($file, $asset, $sumsFile) {
    # "<hash>  <name>", or "<hash> *<name>" when the sum was taken in binary mode.
    $pattern = "\s\*?$([regex]::Escape($asset))$"
    $line = Get-Content $sumsFile | Where-Object { $_ -match $pattern } | Select-Object -First 1
    if (-not $line) { Die "$asset is not listed in SHASUMS256.txt — wrong release, or a partial upload" }
    $expected = ($line -split '\s+')[0]
    # Get-FileHash prints upper case and sha256sum lower; -ne on strings ignores case.
    $actual = (Get-FileHash -Algorithm SHA256 -Path $file).Hash
    if ($expected -ne $actual) { Die "checksum mismatch for $asset`: expected $expected, got $actual" }
}

# ---------------------------------------------------------------- install

# The install directory ends up inside a hook command line, and Codex runs its Windows override
# through `cmd.exe /d /c "<command>"`, where a path containing a space has no spelling that
# survives. Refusing the directory now beats writing a hook that never fires.
if ($target -match '\s') {
    Die ("$prefix contains a space, and a hook command cannot name a path with one. " +
        "Set REMI_PREFIX to a directory without spaces: `$env:REMI_PREFIX = 'C:\remi\bin'")
}

New-Item -ItemType Directory -Force -Path $prefix | Out-Null
$staged = "$target.new"

if ($env:REMI_HOOK_BIN) {
    if (-not (Test-Path -PathType Leaf $env:REMI_HOOK_BIN)) {
        Die "REMI_HOOK_BIN=$env:REMI_HOOK_BIN does not exist"
    }
    Say "installing remi-hook from $env:REMI_HOOK_BIN"
    Copy-Item -Path $env:REMI_HOOK_BIN -Destination $staged -Force
} else {
    $asset = Get-AssetName
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    # The temp directory goes away whatever happens, including the Die paths below — `exit`
    # still runs a finally block.
    try {
        Say "downloading $asset"
        try {
            Save-File (Get-ReleaseUrl $asset) (Join-Path $tmp $asset)
        } catch {
            Die "could not download $asset — check REMI_VERSION, or that the release has that asset"
        }
        try {
            Save-File (Get-ReleaseUrl 'SHASUMS256.txt') (Join-Path $tmp 'SHASUMS256.txt')
        } catch {
            Die 'could not download SHASUMS256.txt'
        }
        Assert-Checksum (Join-Path $tmp $asset) $asset (Join-Path $tmp 'SHASUMS256.txt')
        Copy-Item -Path (Join-Path $tmp $asset) -Destination $staged -Force
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# Windows locks the image of a running program, so an agent mid-turn makes the binary
# impossible to overwrite — but not impossible to rename out of the way. The displaced copy is
# cleared on the next install; it only lingers while something still has it open.
if (Test-Path -PathType Leaf $target) {
    Remove-Item -Force "$target.old" -ErrorAction SilentlyContinue
    Move-Item -Force -Path $target -Destination "$target.old"
}
Move-Item -Force -Path $staged -Destination $target
Say "installed $target"

# ---------------------------------------------------------------- configure

# The binary is in place by now; only the harness configuration is left, and that needs to be
# told which harness. Saying so is better than configuring the wrong agent silently.
if ($args.Count -eq 0) {
    Say 'installed, but no harness was configured.'
    Die 'pass --harness claude-code or --harness codex, e.g. `--harness codex --check`'
}

if (($env:PATH -split ';') -notcontains $prefix) {
    Say "$prefix is not on PATH — run remi-hook as $target, or add the directory yourself"
}

# By full path, never by name, for the same reason: the hooks setup writes name the binary the
# way it was invoked here, and PATH is not what an agent's hook runner is guaranteed to have.
& $target setup @args
exit $LASTEXITCODE
