# CloudTier Dashboard - Robust Launcher
Write-Host "🚀 Initialising CloudTier Dashboard..." -ForegroundColor Cyan

# 1. Start Docker Check
$dockerCheck = docker info 2>&1
if ($lastExitCode -ne 0) {
    Write-Host "⚠️  Docker engine is NOT running!" -ForegroundColor Red
    Write-Host "Action Required: Start 'Docker Desktop' and wait for it to be ready." -ForegroundColor Yellow
    while ($lastExitCode -ne 0) {
        $dockerCheck = docker info 2>&1
        Write-Host "...Waiting for Docker..."
        Start-Sleep -Seconds 5
    }
}
Write-Host "✅ Docker is Ready." -ForegroundColor Green

# 2. Cleanup local "poison" folders (prevent Windows/Linux compatibility issues)
Write-Host "⚙️  Cleaning up local cache files..." -ForegroundColor Gray
Remove-Item -Path "terraform/.terraform" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "terraform/terraform.tfvars" -Force -ErrorAction SilentlyContinue

# 3. Build & Launch
Write-Host "🛠️  Building Dashboard Container..." -ForegroundColor DarkCyan
docker compose down --remove-orphans
docker compose up -d --build

# 4. Success Check
Start-Sleep -Seconds 5
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "🎉 Expansion Platform is READY!" -ForegroundColor Green
Write-Host "Open your browser to: http://localhost:3000" -ForegroundColor White
Write-Host "=========================================`n" -ForegroundColor Cyan
