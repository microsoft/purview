<#   
The MIT License (MIT)

Copyright (c) 2015 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$DocumentLinksFile,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret
)

Add-Type -AssemblyName System.Web

# =============================================
# FUNCTION: Get Access Token
# =============================================
function Get-GraphAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )

    $scope = "https://graph.microsoft.com/.default"
    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $body = @{
        client_id     = $ClientId
        scope         = $scope
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    try {
        Write-Host "Retrieving access token..." -ForegroundColor Cyan
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri $tokenEndpoint `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded"

        Write-Host "✅ Access token retrieved successfully!" -ForegroundColor Green
        Write-Host ""
        return $response.access_token
    }
    catch {
        throw "Failed to retrieve access token: $($_.Exception.Message)"
    }
}

# =============================================
# FUNCTION: Parse document links from CSV file
# =============================================
function Get-DocumentLinksFromCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    Write-Host "Reading CSV file: $FilePath" -ForegroundColor Cyan

    try {
        $csvData = Import-Csv -Path $FilePath
    }
    catch {
        throw "Failed to parse CSV file: $($_.Exception.Message)"
    }

    if ($csvData.Count -eq 0) {
        throw "CSV file is empty or contains no data rows."
    }

    # Check if the required column exists
    $columnName = "SPO document link"
    $hasColumn = $csvData[0].PSObject.Properties.Name -contains $columnName

    if (-not $hasColumn) {
        $availableColumns = ($csvData[0].PSObject.Properties.Name | Sort-Object) -join ", "
        throw "CSV file does not contain the required column: '$columnName'`nAvailable columns: $availableColumns"
    }

    # Extract document links
    $items = @()
    $rowIndex = 1
    $validLinksCount = 0
    $skippedCount = 0

    foreach ($row in $csvData) {
        $documentLink = $row.$columnName

        # Skip rows without a document link or non-SharePoint/OneDrive links
        if ([string]::IsNullOrWhiteSpace($documentLink)) {
            Write-Verbose "Row ${rowIndex}: Skipping - No document link found"
            $skippedCount++
            $rowIndex++
            continue
        }

        # Validate if it's a SharePoint or OneDrive URL
        if ($documentLink -notmatch '^https?://.*sharepoint\.com/') {
            Write-Verbose "Row ${rowIndex}: Skipping - Not a SharePoint/OneDrive link: $documentLink"
            $skippedCount++
            $rowIndex++
            continue
        }

        $validLinksCount++
        $items += [PSCustomObject]@{
            RowNumber    = $rowIndex
            DocumentLink = $documentLink.Trim()
        }

        $rowIndex++
    }

    if ($items.Count -eq 0) {
        throw "No valid SharePoint or OneDrive document links found in CSV file."
    }

    Write-Host "Total rows processed: $($csvData.Count)" -ForegroundColor Cyan
    Write-Host "Valid document links found: $validLinksCount" -ForegroundColor Green
    Write-Host "Rows skipped (no link or non-SPO): $skippedCount" -ForegroundColor Yellow
    Write-Host ""

    return ,$items
}

# =============================================
# FUNCTION: Detect URL type (SharePoint or OneDrive)
# =============================================
function Get-DocumentLinkType {
    param([System.Uri]$Uri)

    $path = $Uri.AbsolutePath
    
    if ($path -match "^/personal/") {
        return "OneDrive"
    }
    elseif ($path -match "^/sites/") {
        return "SharePoint"
    }
    else {
        throw "Unsupported URL structure. Expected /sites/ or /personal/ in the path."
    }
}

# =============================================
# FUNCTION: Resolve Graph item for SharePoint URL
# =============================================
function Resolve-SharePointItem {
    param(
        [System.Uri]$Uri,
        [hashtable]$Headers
    )

    $siteHost = $Uri.Host
    $absolutePath = $Uri.AbsolutePath.TrimStart('/')

    # Extract site path (e.g., sites/my-site)
    if ($absolutePath -match "^(sites/[^/]+)") {
        $sitePath = $matches[1]
    }
    else {
        throw "Could not determine site path from URL."
    }

    # Extract the file path after the document library
    # Typical SharePoint URLs: /sites/{site}/Shared Documents/{filepath}
    #                       or /sites/{site}/{library}/{filepath}
    $decodedPath = [System.Web.HttpUtility]::UrlDecode($absolutePath)
    $relativePath = $null

    # Common document library names to strip from the path
    $libraryPatterns = @(
        'Shared Documents',
        'Documents',
        'Shared%20Documents'
    )

    # Try to extract path after known library names
    foreach ($library in $libraryPatterns) {
        $pattern = "^sites/[^/]+/$library/(.+)$"
        if ($decodedPath -match $pattern) {
            $relativePath = $matches[1]
            break
        }
    }

    # If no standard library matched, try generic pattern (any library name)
    if (-not $relativePath) {
        # Pattern: sites/{site}/{anything}/{filepath}
        if ($decodedPath -match "^sites/[^/]+/[^/]+/(.+)$") {
            $relativePath = $matches[1]
        }
    }

    if (-not $relativePath) {
        throw "Could not extract file path from SharePoint URL. URL: $decodedPath"
    }

    Write-Verbose "Site Host  : $siteHost"
    Write-Verbose "Site Path  : $sitePath"
    Write-Verbose "File Path  : $relativePath"

    # Get Site ID
    $siteUrl = "https://graph.microsoft.com/v1.0/sites/${siteHost}:/${sitePath}"
    Write-Verbose "Getting Site ID: $siteUrl"

    $siteResponse = Invoke-RestMethod -Method GET -Uri $siteUrl -Headers $Headers
    $siteId = $siteResponse.id
    Write-Verbose "Site ID    : $siteId"

    # Resolve file item using site drive and relative path
    $encodedPath = [System.Web.HttpUtility]::UrlPathEncode($relativePath)
    $getUri = "https://graph.microsoft.com/v1.0/sites/$siteId/drive/root:/$encodedPath"
    Write-Verbose "Resolving item: $getUri"

    $item = Invoke-RestMethod -Method GET -Uri $getUri -Headers $Headers

    return @{
        ItemId  = $item.id
        DriveId = $item.parentReference.driveId
        Name    = $item.name
    }
}

# =============================================
# FUNCTION: Resolve Graph item for OneDrive URL
# =============================================
function Resolve-OneDriveItem {
    param(
        [System.Uri]$Uri,
        [hashtable]$Headers
    )

    $decodedPath = [System.Web.HttpUtility]::UrlDecode($Uri.AbsolutePath)
    $segments = $decodedPath -split "/"

    # /personal/{user_part}/Documents/{path}
    if ($segments[1] -ne "personal" -or $segments.Length -lt 4) {
        throw "Unexpected OneDrive personal URL format."
    }

    $userPart = $segments[2]  # e.g., yueqiwang_m365p893818_onmicrosoft_com

    # Split by underscores
    $parts = $userPart -split "_"

    if ($parts.Length -lt 2) {
        throw "Cannot determine user email from URL segment: $userPart"
    }

    # Strategy: The domain typically ends with known patterns like "_onmicrosoft_com" or similar
    # We'll try from right to left, looking for valid domain patterns
    # Common pattern: last 3+ parts form domain (e.g., m365p893818_onmicrosoft_com)
    
    $email = $null
    $lastError = $null
    
    # Start from assuming the last 2 parts are domain (minimum: domain_tld)
    # Then try 3 parts, 4 parts, etc.
    for ($domainParts = 2; $domainParts -lt $parts.Length; $domainParts++) {
        $usernameParts = $parts.Length - $domainParts
        $candidateUser = ($parts[0..($usernameParts - 1)] -join "_")
        $candidateDomain = ($parts[$usernameParts..($parts.Length - 1)] -join ".")
        $candidateEmail = "$candidateUser@$candidateDomain"

        Write-Verbose "Trying email: $candidateEmail"

        try {
            # First, try to use this email to access the drive directly
            # This validates the email without requiring user lookup permissions
            $testUri = "https://graph.microsoft.com/v1.0/users/$candidateEmail/drive"
            $null = Invoke-RestMethod -Method GET -Uri $testUri -Headers $Headers -ErrorAction Stop
            $email = $candidateEmail
            Write-Verbose "Successfully validated: $email"
            break
        }
        catch {
            $lastError = $_
            # If it's a 404 or "user not found", try next split
            # If it's a permission error but the user exists, use it anyway
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 403) {
                # Forbidden means the user exists but we don't have permission
                # This is acceptable for our purposes
                $email = $candidateEmail
                Write-Verbose "User exists (403 response): $email"
                break
            }
            # Otherwise continue trying other splits
            continue
        }
    }

    if (-not $email) {
        throw "Could not determine user email from URL segment '$userPart'. Last error: $($lastError.Exception.Message)"
    }

    Write-Verbose "User Email : $email"

    # Extract library name and file path after /personal/{user}/{library}/{filepath}
    if ($decodedPath -match "^/personal/[^/]+/([^/]+)/(.+)$") {
        $libraryName = $matches[1]
        $relativeFilePath = $matches[2]
    }
    else {
        throw "Could not extract file path from OneDrive URL: $decodedPath"
    }

    Write-Verbose "Library    : $libraryName"
    Write-Verbose "File Path  : $relativeFilePath"

    # Resolve item via Graph
    # For non-default libraries (e.g. PreservationHoldLibrary), use drives endpoint
    if ($libraryName -eq "Documents") {
        $encodedPath = [System.Web.HttpUtility]::UrlPathEncode("/$relativeFilePath")
        $getUri = "https://graph.microsoft.com/v1.0/users/$email/drive/root:$encodedPath"
    }
    else {
        # List all drives for the user and find the matching library
        $targetDrive = $null

        # First try user-level drives endpoint
        try {
            $drivesUri = "https://graph.microsoft.com/v1.0/users/$email/drives"
            $drivesResponse = Invoke-RestMethod -Method GET -Uri $drivesUri -Headers $Headers
            $targetDrive = $drivesResponse.value | Where-Object { $_.name -eq $libraryName }
        }
        catch {
            Write-Verbose "Could not list user drives: $($_.Exception.Message)"
        }

        # Fall back to site-level drives (finds hidden libraries like PreservationHoldLibrary)
        if (-not $targetDrive) {
            try {
                $siteHost = $Uri.Host
                $siteUri = "https://graph.microsoft.com/v1.0/sites/${siteHost}:/personal/${userPart}"
                $siteResponse = Invoke-RestMethod -Method GET -Uri $siteUri -Headers $Headers
                $siteId = $siteResponse.id

                $siteDrivesUri = "https://graph.microsoft.com/v1.0/sites/$siteId/drives"
                $siteDrivesResponse = Invoke-RestMethod -Method GET -Uri $siteDrivesUri -Headers $Headers
                $targetDrive = $siteDrivesResponse.value | Where-Object { $_.name -eq $libraryName }
            }
            catch {
                Write-Verbose "Could not list site drives: $($_.Exception.Message)"
            }
        }

        if (-not $targetDrive) {
            throw "Could not find drive/library '$libraryName' for user $email"
        }

        $encodedPath = [System.Web.HttpUtility]::UrlPathEncode("/$relativeFilePath")
        $getUri = "https://graph.microsoft.com/v1.0/drives/$($targetDrive.id)/root:$encodedPath"
    }

    Write-Verbose "Resolving item: $getUri"

    $item = Invoke-RestMethod -Method GET -Uri $getUri -Headers $Headers

    return @{
        ItemId  = $item.id
        DriveId = $item.parentReference.driveId
        Name    = $item.name
    }
}

# =============================================
# FUNCTION: Delete a single file
# =============================================
function Remove-GraphFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DocumentLink,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    try {
        $uri = [System.Uri]$DocumentLink
    }
    catch {
        throw "Invalid URL: $_"
    }

    $linkType = Get-DocumentLinkType -Uri $uri

    # Resolve item ID and drive ID
    if ($linkType -eq "SharePoint") {
        $itemInfo = Resolve-SharePointItem -Uri $uri -Headers $Headers
    }
    else {
        $itemInfo = Resolve-OneDriveItem -Uri $uri -Headers $Headers
    }

    $itemId  = $itemInfo.ItemId
    $driveId = $itemInfo.DriveId
    $fileName = $itemInfo.Name

    if (-not $itemId -or -not $driveId) {
        throw "Could not retrieve required item properties."
    }

    # Delete via Graph API
    $deleteUri = "https://graph.microsoft.com/v1.0/drives/$driveId/items/$itemId"
    Invoke-RestMethod -Method DELETE -Uri $deleteUri -Headers $Headers

    return $fileName
}

# =============================================
# MAIN EXECUTION
# =============================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Microsoft Graph Batch File Deletion Tool" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Fetch access token
try {
    $accessToken = Get-GraphAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
}
catch {
    Write-Error $_
    exit 1
}

$headers = @{
    Authorization  = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Parse document links from CSV file
try {
    $documentItems = Get-DocumentLinksFromCsv -FilePath $DocumentLinksFile
}
catch {
    Write-Error $_
    exit 1
}

# Display all files to be deleted
Write-Host "Files to be deleted:" -ForegroundColor Yellow
foreach ($item in $documentItems) {
    Write-Host "  Row $($item.RowNumber): $($item.DocumentLink)" -ForegroundColor White
}
Write-Host ""

# Confirm batch deletion
$confirmation = Read-Host "Are you sure you want to delete ALL $($documentItems.Count) file(s)? (YES to confirm)"
if ($confirmation -ne "YES") {
    Write-Host "Batch deletion cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting batch deletion..." -ForegroundColor Cyan
Write-Host ""

# Track results
$results = @()
$successCount = 0
$failureCount = 0

# Process each document link
$processedIndex = 1
foreach ($item in $documentItems) {
    Write-Host "[$processedIndex/$($documentItems.Count)] Processing Row $($item.RowNumber):" -ForegroundColor Cyan
    Write-Host "  URL: $($item.DocumentLink)" -ForegroundColor Gray

    try {
        $deletedFileName = Remove-GraphFile -DocumentLink $item.DocumentLink -Headers $headers
        Write-Host "  ✅ Deleted successfully: $deletedFileName" -ForegroundColor Green
        $successCount++
        $results += [PSCustomObject]@{
            RowNumber       = $item.RowNumber
            DocumentLink    = $item.DocumentLink
            DeletedFileName = $deletedFileName
            Status          = "Success"
            Error           = ""
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 404) {
            Write-Host "  ✅ File not found (already deleted or does not exist) - treating as success" -ForegroundColor Green
            $successCount++
            $results += [PSCustomObject]@{
                RowNumber       = $item.RowNumber
                DocumentLink    = $item.DocumentLink
                DeletedFileName = "N/A (not found)"
                Status          = "Success (Not Found)"
                Error           = ""
            }
        }
        elseif ($errorMessage -match "Could not find drive/library") {
            Write-Host "  ✅ Drive/library not found (already removed) - treating as success" -ForegroundColor Green
            $successCount++
            $results += [PSCustomObject]@{
                RowNumber       = $item.RowNumber
                DocumentLink    = $item.DocumentLink
                DeletedFileName = "N/A (library not found)"
                Status          = "Success (Library Not Found)"
                Error           = ""
            }
        }
        elseif ($statusCode -eq 423) {
            Write-Host "  ❌ Failed: File is locked (HTTP 423)" -ForegroundColor Red
            Write-Host "     The file is currently open or locked. Close it and retry." -ForegroundColor Yellow
            $errorMessage = "File is locked (HTTP 423)"
            $failureCount++
            $results += [PSCustomObject]@{
                RowNumber       = $item.RowNumber
                DocumentLink    = $item.DocumentLink
                DeletedFileName = "N/A"
                Status          = "Failed"
                Error           = $errorMessage
            }
        }
        else {
            Write-Host "  ❌ Failed: $errorMessage" -ForegroundColor Red
            $failureCount++
            $results += [PSCustomObject]@{
                RowNumber       = $item.RowNumber
                DocumentLink    = $item.DocumentLink
                DeletedFileName = "N/A"
                Status          = "Failed"
                Error           = $errorMessage
            }
        }
    }

    Write-Host ""
    $processedIndex++
}

# Summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Batch Deletion Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Total files processed: $($documentItems.Count)" -ForegroundColor White
Write-Host "Successfully deleted : $successCount" -ForegroundColor Green
Write-Host "Failed to delete     : $failureCount" -ForegroundColor Red
Write-Host ""

# Display detailed results
if ($failureCount -gt 0) {
    Write-Host "Failed deletions:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  [Row $($_.RowNumber)] $($_.DocumentLink)" -ForegroundColor Yellow
        Write-Host "      Error: $($_.Error)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Export results to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path (Get-Location) "DeletionReport_$timestamp.csv"
$results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Detailed report exported to: $reportPath" -ForegroundColor Cyan
Write-Host ""
