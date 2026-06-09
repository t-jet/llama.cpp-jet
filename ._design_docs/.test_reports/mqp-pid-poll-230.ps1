$pids = @(31580, 25756, 12952)
foreach ($p in $pids) {
    $proc = Get-Process -Id $p -ErrorAction SilentlyContinue
    if ($null -eq $proc) {
        Write-Output ("PID {0,-7} GONE" -f $p)
    } else {
        $up = (Get-Date) - $proc.StartTime
        $cpu = [Math]::Round($proc.CPU, 1)
        $ws = [Math]::Round($proc.WorkingSet64 / 1MB, 1)
        $st = $proc.StartTime.ToString('HH:mm:ss')
        Write-Output ("PID {0,-7} {1,-14} CPU={2,7} WS={3,7}MB Start={4} Uptime={5}" -f $proc.Id, $proc.ProcessName, $cpu, $ws, $st, $up)
    }
}
