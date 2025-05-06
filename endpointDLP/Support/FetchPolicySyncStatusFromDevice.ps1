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
    $formattedDate = $localTime.ToString("yyyy-MM-dd HH:mm:ss")

    return $formattedDate
}

# Fetch the events
$events = Get-WinEvent -LogName $logType | Where-Object { $eventIDs -contains $_.Id }

$policySyncData = $events | ForEach-Object {
    $policyHashParts = ($_.Message -replace ".*Policy Hash: ([\w-]+).*", '$1') -split "-"
    $policyType = ""
    if ($_.Message -match "DLP policy type: (\w+)\.") {
        $policyType = $matches[1]
    }
     
    if ($policyType -notmatch "ActionsOverridePolicy|ColdData") {
        [PSCustomObject]@{
            EventTimestamp = $_.TimeCreated
            DeviceName = $_.MachineName
            DeviceId = Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
            PolicyType = $policyType
            PolicyVersionHash = $policyHashParts[1]
            LastModifiedTime = Convert-EventTimeToDate -eventTime $policyHashParts[0]
            Status = if ($_.Id -eq 131) { "Success" } else { "Received" }
        }
    }
}

# Group by PolicyVersionHash and get the latest LastModifiedTime across all policies
$latestPolicySyncData = $policySyncData | Group-Object -Property PolicyType | ForEach-Object {
    $sortedGroup = $_.Group | Sort-Object -Property EventTimestamp -Descending
    $successEvent = $sortedGroup | Where-Object { $_.Status -eq "Success" } | Select-Object -First 1
    if ($successEvent) {
        $successEvent
    } else {
        $sortedGroup | Select-Object -First 1
    }
}

# Output the JSON string
Write-Output $latestPolicySyncData
