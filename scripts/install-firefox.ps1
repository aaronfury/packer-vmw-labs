Import-Module "C:\Temp\BuildFunctions.psm1"

$firefoxURI = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
$firefoxFile = "C:\Temp\firefox.exe"

Get-WebFile -SourceURI $firefoxURI -TargetFile $firefoxFile

Start-ExternalProcess -Executable $firefoxFile -Arguments "/S"