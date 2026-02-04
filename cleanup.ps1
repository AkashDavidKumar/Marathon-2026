# Cleanup Script for AWS Migration Folder
$keepList = @(
    "cloudformation-template.yaml",
    "user_data_optimized.sh",
    "nginx-optimized.conf",
    "supervisor-real.conf",
    "update-infrastructure-v3.ps1",
    "create_dashboard.ps1",
    "optimize_performance.ps1",
    "monitor.py",
    "load_test.py",
    "deploy-socket-fix-v2.ps1",
    "requirements.txt",
    "wsgi.py",
    ".env",
    "debug-marathon-key-v2.pem",
    "README.md",
    "cleanup.ps1"
)

$files = Get-ChildItem -File
$count = 0

foreach ($file in $files) {
    if ($file.Name -notin $keepList) {
        Remove-Item $file.FullName -Force
        Write-Host "Deleted: $($file.Name)"
        $count++
    }
}

Write-Host "Cleanup Complete. Deleted $count files."

# Renaming for clarity
if (Test-Path "user_data_optimized.sh") { Rename-Item "user_data_optimized.sh" "user_data.sh" }
if (Test-Path "update-infrastructure-v3.ps1") { Rename-Item "update-infrastructure-v3.ps1" "deploy_infrastructure.ps1" }
if (Test-Path "deploy-socket-fix-v2.ps1") { Rename-Item "deploy-socket-fix-v2.ps1" "patch_servers.ps1" }

Write-Host "Files Renamed to standard names."
