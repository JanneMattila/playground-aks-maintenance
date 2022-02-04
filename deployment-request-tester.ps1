param (
    [Parameter(Mandatory = $true)] 
    [string] $Url,
    [int] 
    $Delay = 10,
    
    [int] 
    $Count = 99999,
    
    [int] 
    $TimeoutValue = 99999
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

For ($i = 0; $i -lt $Count; $i++) {
    $startTime = Get-Date
    try {
        $response = Invoke-WebRequest -Method GET -Uri $Url -DisableKeepAlive
        if ($response.StatusCode -ne 200) {
            Write-Output "$TimeoutValue"
        }
        else {
            $endTime = Get-Date
            $executionTime = ($endTime - $startTime).TotalMilliseconds -as [int]
            Write-Output "$executionTime ($Delay) $($response.Content.Trim())" 
        }
    }
    catch {
        Write-Output "Request failed"
    }

    if ([Console]::KeyAvailable) {
        $pressedKey = [Console]::ReadKey($true)
        $change = $Delay * 0.1
        if ($change -lt 1) {
            $change = 1
        }
        switch ($pressedKey.Key) {
            UpArrow {
                $Delay += $change
            }
            DownArrow {
                $Delay -= $change
                if (0 -gt $Delay) {
                    $Delay = 0
                }
            }
            Default {}
        }
    }

    Start-Sleep -Milliseconds $Delay
}
