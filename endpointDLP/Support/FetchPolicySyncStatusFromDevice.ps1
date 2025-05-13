# Define the log type and source
$logType = "Microsoft-Windows-SENSE/Operational"

# Define the event IDs to fetch
$eventIDs = @(130, 131)

function Convert-EventTimeToDate {
    param (
        [uint64]$eventTime
    )

    # Define the epoch time for Windows event time
    $epochTime = 504911232000000000

    # Check if the event time is valid
    if ($eventTime -lt $epochTime) {
        return "Invalid timestamp"
    }

    # Calculate the difference from the epoch time
    $eventTime -= $epochTime

    # Convert the event time to a DateTime object
    $dateTime = [datetime]::FromFileTimeUtc($eventTime)

    # Get the current time zone
    $timeZone = [System.TimeZoneInfo]::Local

    # Convert to local time
    $localTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($dateTime, $timeZone)

    # Format the date and time
    $formattedDate = $localTime.ToString("yyyy-MM-dd HH:mm:ss 'UTC'")

    return $formattedDate
}

# Fetch the events
$events = Get-WinEvent -LogName $logType | Where-Object { $eventIDs -contains $_.Id }

$policySyncData = $events | ForEach-Object {
    $message = $_.Message

    $lastModifiedRaw = $null
    $versionHash = "Missing or invalid"

    if ($message -match "Policy Hash: ([\w]+)-([\w]+)") {
        $lastModifiedRaw = $matches[1]
        $versionHash = $matches[2]
    }

    $policyType = if ($message -match "DLP policy type: (\w+)\.") {
        $matches[1]
    } else {
        "Unknown Policy Type"
    }
     
    if ($policyType -notmatch "ActionsOverridePolicy|ColdData") {
        [PSCustomObject]@{
            EventTimestamp    = $_.TimeCreated.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
            DeviceName        = $_.MachineName
            DeviceId          = Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
            PolicyType        = $policyType
            PolicyVersionHash = $versionHash
            LastModifiedTime  = if ($lastModifiedRaw) { Convert-EventTimeToDate -eventTime $lastModifiedRaw } else { "Invalid timestamp" }
            Status            = if ($_.Id -eq 131) { "Success" } else { "Received" }
        }
    }
}

$latestPolicySyncData = @()

# Group by PolicyVersionHash and get the latest LastModifiedTime across all policies
$groupedData = $policySyncData | Group-Object -Property PolicyType

foreach ($group in $groupedData) {
    $sortedGroup = $group.Group | Sort-Object -Property EventTimestamp -Descending
    $selected = $sortedGroup | Where-Object { $_.Status -eq "Success" } | Select-Object -First 1
    if (-not $selected) {
        $selected = $sortedGroup | Select-Object -First 1
    }
    $latestPolicySyncData += $selected
}

# Output the JSON string
Write-Output $latestPolicySyncData | ConvertTo-Json -Depth 4

