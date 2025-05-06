$resultMessages = @() 
foreach ($item in $response.value) {
    $resultMessages += $item.resultMessage
}

# Split the data into individual messages
$messages = $resultMessages -split "\r\n\r\n"

# Initialize an array to store the converted objects
$psCustomObjects = @()

foreach ($message in $messages) {
    # Split each message into key-value pairs
    $properties = $message -split "\r\n"
    $object = [PSCustomObject]@{}
    foreach ($property in $properties) {
        $key, $value = $property -split ":", 2
        $object | Add-Member -MemberType NoteProperty -Name $key.Trim() -Value $value.Trim()
    }
    $psCustomObjects += $object
}

# Export to CSV
$psCustomObjects | Export-Csv -Path "resultMessages.csv" -NoTypeInformation

