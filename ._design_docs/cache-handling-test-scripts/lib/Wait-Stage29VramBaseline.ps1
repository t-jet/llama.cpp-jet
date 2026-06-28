#requires -Version 5
# Wait-Stage29VramBaseline.ps1
#
# Stage 29 lib helper: VRAM cooldown gate per design part-03 lines
# 95-110. Sleeps for SleepSec seconds, then polls nvidia-smi every
# PollIntervalSec seconds until VRAM drops to within ToleranceMiB of
# BaselineMiB or MaxWaitSec elapses. Returns the cooldown result so
# the driver can record actual durations in summary.json.
#
# Public entry point: Wait-Stage29VramBaseline
# Output schema: stage29-vram-cooldown-v1
#
# Usage:
#   . .\lib\Wait-Stage29VramBaseline.ps1
#   $cooldown = Wait-Stage29VramBaseline -BaselineMiB 1200 -ToleranceMiB 100 `
#       -MaxWaitSec 120 -SleepSec 30
#   if ($cooldown.Status -eq 'BLOCKED-vram-release') { throw 'VRAM not released' }
#
# Per design D29-DESIGN-06 (30s sleep + nvidia-smi VRAM back-to-baseline
# gate), the polling cap is 120s (MaxWaitSec default). The Stage 29
# driver calls this helper with -MaxWaitSec 60 in Phase 0.5/Phase 1 and
# -MaxWaitSec 120 in Phase 2/Phase 3 cycle legs. Callers may override
# MaxWaitSec for tighter or looser hosts.

param()

$ErrorActionPreference = 'Stop'

function Get-NvidiaSmiMemoryUsedMiB {
    [CmdletBinding()]
    param([int] $TimeoutSec = 10)

    $output = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Get-NvidiaSmiMemoryUsedMiB: nvidia-smi exit code $LASTEXITCODE"
    }
    $first = ($output -split "`n")[0].Trim()
    return [int]$first
}

function Wait-Stage29VramBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [int] $BaselineMiB,
        [int] $ToleranceMiB   = 100,
        [int] $SleepSec       = 30,
        [int] $PollIntervalSec = 5,
        [int] $MaxWaitSec     = 120
    )

    $startUnix = [int][double]::Parse((Get-Date -UFormat %s))

    Write-Output "Wait-Stage29VramBaseline: sleeping $SleepSec seconds before polling"
    Start-Sleep -Seconds $SleepSec

    $vramAfterSleep = Get-NvidiaSmiMemoryUsedMiB
    $threshold = $BaselineMiB + $ToleranceMiB
    $deadline = $startUnix + $SleepSec + $MaxWaitSec

    $vramAfterRelease = $vramAfterSleep
    $pollIterations = 0

    while ($true) {
        $nowUnix = [int][double]::Parse((Get-Date -UFormat %s))
        if ($nowUnix -ge $deadline) { break }

        $current = Get-NvidiaSmiMemoryUsedMiB
        $vramAfterRelease = $current
        $pollIterations++

        if ($current -le $threshold) {
            break
        }

        Start-Sleep -Seconds $PollIntervalSec
    }

    $endUnix = [int][double]::Parse((Get-Date -UFormat %s))
    $duration = $endUnix - $startUnix
    $status = if ($vramAfterRelease -le $threshold) { 'PASS' } else { 'BLOCKED-vram-release' }

    return [pscustomobject]@{
        Status                    = $status
        BaselineMiB               = $BaselineMiB
        ToleranceMiB              = $ToleranceMiB
        VramAfterSleepMiB         = $vramAfterSleep
        VramAfterReleaseMiB       = $vramAfterRelease
        ThresholdMiB              = $threshold
        CooldownDurationSeconds   = $duration
        PollIterations            = $pollIterations
    }
}
