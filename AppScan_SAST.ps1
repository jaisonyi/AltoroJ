$PSVersionTable
ls
dir env:
Write-Host $env:ASOC_SCAN_NAME
Write-Host $env:ASOC_APPID
$baseURL = 'https://cloud.appscan.com/api/V2'
$env:ASoC_IRX_Config_file = "appscan-config.xml"
$bearer_token =''

# ASoC - Login to ASoC with API Key and Secret
$jsonBody = "
  {
  `"KeyId`": `"$env:ASOC_KEY_ID`",
  `"KeySecret`": `"$env:ASOC_KEY_SECRET`"
  }
"
$params = @{
Uri         = "$baseURL/Account/ApiKeyLogin"
Method      = 'POST'
Body        = $jsonBody
Headers = @{
    'Content-Type' = 'application/json'
  }
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
$Members = Invoke-RestMethod @params
Write-Host "Auth successful - Token received: $Members.token"
$bearer_token = $Members.token
$ProgressPreference = 'SilentlyContinue'
