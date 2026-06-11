$procs = Get-Process -Id 31580,25756,12952 -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($p in $procs) {
        $uptime = (Get-Date) - $p.StartTime
        $uptimeStr = ('{0}:{1:D2}:{2:D2}' -f [int]$uptime.TotalHours, $uptime.Minutes, $uptime.Seconds)
        $wsMB = [int]($p.WorkingSet64 / 1MB)
        Write-Host ("PID={0} Name={1} CPU={2} Uptime={3} WS_MB={4} StartTime={5:HH:mm:ss}" -f $p.Id, $p.ProcessName, $p.CPU.ToString('F1'), $uptimeStr, $wsMB, $p.StartTime)
    }
} else {
    Write-Host "No matching PIDs found"
}
