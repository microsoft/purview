$csvData = @()

foreach ($item in $response.value) {
    $messageObject = $item.resultMessage | ConvertFrom-Json
    $csvData += [PSCustomObject]$messageObject
}

$csvData | Select-Object EventTimestamp, DeviceName, DeviceId, PolicyType, PolicyVersionHash, LastModifiedTime, Status | Export-Csv -Path "resultMessages.csv" -NoTypeInformation




