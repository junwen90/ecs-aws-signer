$url = 'https://releases.hashicorp.com/terraform/1.15.6/terraform_1.15.6_windows_amd64.zip'
$zip = 'terraform.zip'
$dest = $PWD

Write-Host "Downloading Terraform 1.15.6..."
Invoke-WebRequest -Uri $url -OutFile $zip
Write-Host "Download complete. Extracting..."
Expand-Archive -Path $zip -DestinationPath $dest -Force
Remove-Item $zip
Write-Host "Terraform installed successfully!"
& .\terraform.exe version
