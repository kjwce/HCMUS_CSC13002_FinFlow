param(
    [Parameter(Mandatory = $true)]
    [string]$token
)

$functionUrl = 'https://kwatnxelpnohpjpwsqrb.supabase.co/functions/v1/parse-natural-language-transaction'
$currentDate = [DateTimeOffset]::Now.ToString('yyyy-MM-dd')
$currentDateTime = [DateTimeOffset]::Now.ToString('o')

$categories = @(
    @{ key = 'Food'; label = 'Food' }
    @{ key = 'Car'; label = 'Car' }
    @{ key = 'Gift'; label = 'Gift' }
    @{ key = 'Health'; label = 'Health' }
    @{ key = 'Clothes'; label = 'Clothes' }
    @{ key = 'Home'; label = 'Home' }
    @{ key = 'Donation'; label = 'Donation' }
    @{ key = 'Beauty'; label = 'Beauty' }
    @{ key = 'Transport'; label = 'Transport' }
    @{ key = 'Shopping'; label = 'Shopping' }
    @{ key = 'Subscription'; label = 'Subscription' }
    @{ key = 'Bills'; label = 'Bills' }
    @{ key = 'Salary'; label = 'Salary' }
    @{ key = 'Other'; label = 'Other' }
)

$wallets = @(
    @{
        id        = 'test-wallet-momo'
        name      = 'MoMo'
        shortName = 'MOMO'
        type      = 'ewallet'
        isActive  = $true
    }
)

$testCases = @(
    @{
        name   = 'Vietnamese expense'
        locale = 'vi-VN'
        text   = 'Ăn trưa 50k bằng MoMo hôm qua'
    }
    @{
        name   = 'English expense'
        locale = 'en-US'
        text   = 'Paid 120k for lunch yesterday'
    }
    @{
        name   = 'Unknown category fallback'
        locale = 'vi-VN'
        text   = 'Mua vé xem phim 120k'
    }
)

$headers = @{
    Authorization = "Bearer $token"
}

foreach ($testCase in $testCases) {
    $body = @{
        text            = $testCase.text
        currentDate     = $currentDate
        currentDateTime = $currentDateTime
        timezone        = 'Asia/Ho_Chi_Minh'
        locale          = $testCase.locale
        categories      = $categories
        wallets         = $wallets
    } | ConvertTo-Json -Depth 8

    Write-Host "`n=== $($testCase.name) ==="

    try {
        $response = Invoke-RestMethod `
            -Uri $functionUrl `
            -Method Post `
            -Headers $headers `
            -ContentType 'application/json; charset=utf-8' `
            -Body $body

        $response | ConvertTo-Json -Depth 10
    }
    catch {
        if ($_.ErrorDetails.Message) {
            try {
                $_.ErrorDetails.Message | ConvertFrom-Json |
                    ConvertTo-Json -Depth 10
            }
            catch {
                Write-Host $_.ErrorDetails.Message
            }
        }
        else {
            Write-Host $_.Exception.Message
        }
    }
}
