$PSVersionTable
ls
dir env:
Write-Host $env:ASOC_SCAN_NAME
Write-Host $env:ASOC_APPID
$baseURL = 'https://cloud.appscan.com/api/V2'
$env:ASoC_IRX_Config_file = "appscan-config.xml"
$bearer_token =''

if (-Not (Test-Path -Path $env:ASoC_IRX_Config_file -PathType Leaf)){
    Write-Error "$env:ASoC_IRX_Config_file not found, exiting..."
    exit $LASTEXITCODE 
  }

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

# ASoC -  Download the latest version of SAClientUtil to generate the .irx in preparation for the scan
Write-Host "Downloading latest verion of SAClientUtil..."
Invoke-WebRequest -Uri "https://cloud.appscan.com/api/Local/StaticAnalyzer/ARSATool" -OutFile "saclientutil.zip"
Expand-Archive -Path "saclientutil.zip" -DestinationPath "saclientutil"
$SAClientUtilFolder = Get-ChildItem -Path .\saclientutil
$command = ".\saclientutil\" + $SAClientUtilFolder.name + "\bin\appscan.bat"
& $command prepare -c $env:ASoC_IRX_Config_file -n output.irx

# Comment out this lines for a proper .irx generation. This line is for demo purposes, it only downloads a sample .irx file that is not related to the source code in this repo
# Invoke-WebRequest -Uri "https://cloud.appscan.com/api/V2/Tools/ScanDemoFiles/StaticAnalyzer" -OutFile "output.irx"
# ASoC - Upload the .irx file onto ASoC
$irx_file = [IO.File]::ReadAllBytes('output.irx')
$params = @{
  Uri         = "$baseURL/FileUpload"
  Method      = 'Post'
  Headers = @{
    'Content-Type' = 'multipart/form-data'
    Authorization = "Bearer $bearer_token"
  }
   Form = @{
  'fileToUpload' = Get-Item -Path "output.irx"
 }
}
$upload = Invoke-RestMethod @params
$upload_File_ID = $upload.FileId
write-host "IRX Uploaded File ID: $upload_File_ID"

# ASoC - Execute a Static (SAST) Scan on ASoC by specifying the upload_File_ID

$params = @{
  Uri         = "$baseURL/Scans/StaticAnalyzer"
  Method      = 'Post'
  Headers = @{
    'Content-Type' = 'application/json'
    Authorization = "Bearer $bearer_token"
  }
}
$body = @{
   'ApplicationFileId' = "$upload_File_ID"
   'ScanName' = "$env:ASOC_SCAN_NAME"
   'EnableMailNotification' = "true"
   'Locale' = "en-US"
   'AppId' = "$env:ASOC_APPID"
   'Execute' = "true"
   'FullyAutomatic' = "false"
   'Personal' = "false"
}
$output_runscan = Invoke-RestMethod @params -Body ($body|ConvertTo-JSON)
write-host "Scan executed"
Write-Host $output_runscan
$scan_ID = $output_runscan.Id

# ASoC - Checking for scan completion status

$params = @{
  Uri         = "$baseURL/Scans/$scan_ID/Executions"
  Method      = 'Get'
  Headers = @{
    'Content-Type' = 'application/json'
    Authorization = "Bearer $bearer_token"
  }
}
$scan_status ="Not Ready"
while($scan_status -ne "Ready"){
  $output = Invoke-RestMethod @params
  $scan_status = $output.Status
  Start-Sleep -Seconds 10
  Write-Host "Waiting for Scan Completion..."
}

# ASoC - Generate a HTML report on the completed scan by specifying the scan_ID

$params = @{
  Uri         = "$baseURL/Reports/Security/Scan/$scan_ID"
  Method      = 'Post'
  Headers = @{
    'Content-Type' = 'application/json'
    Authorization = "Bearer $bearer_token"
  }
}
$body = @{
  'Configuration' = @{
    'Summary' = "true"
    'Details' = "true"
    'Discussion' = "true"
    'Overview' = "true"
    'TableOfContent' = "true"
    'Advisories' = "true"
    'FixRecommendation' = "true"
    'History' = "true"
    'Coverage' = "true"
    'MinimizeDetails' = "true"
    'Articles' = "true"
    'ReportFileType' = "HTML"
    'Title' = "false"
    'Locale' = "en-US"
  }
}
$output_runreport = Invoke-RestMethod @params -Body ($body|ConvertTo-JSON)
$report_ID = $output_runreport.Id
#Wait for report
$params = @{
  Uri         = "$baseURL/Reports/$report_ID"
  Method      = 'Get'
  Headers = @{
    'Content-Type' = 'application/json'
    Authorization = "Bearer $bearer_token"
  }
}
$report_status ="Not Ready"
while($report_status -ne "Ready"){
  $output = Invoke-RestMethod @params
  $report_status = $output.Status
  Start-Sleep -Seconds 5
  Write-Host "Generating Report... Progress: " $output.Progress "%"
}
#Download Report
$params = @{
  Uri         = "$baseURL/Reports/Download/$report_ID"
  Method      = 'Get'
  Headers = @{
    'Accept' = 'text/html'
    Authorization = "Bearer $bearer_token"
  }
}
$output_runreport = Invoke-RestMethod @params
Out-File -InputObject $output_runreport -FilePath .\AppScan_Security_Report.html
