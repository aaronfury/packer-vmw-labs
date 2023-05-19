# Create Target Folders
@(
	"C:\Temp"
) | ForEach-Object {
	Write-Host "Creating folder $_"
	try {
		[void]($folder = New-Item -Path $_ -ItemType Directory -Force)
		$folder.Attributes += "Hidden"
	} catch {
		Write-Host "ERROR: Failed to create folder"
		Write-Host "ERROR:" $_.Exception.Message
		exit 1
	}
}