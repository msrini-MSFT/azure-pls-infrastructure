<#
.SYNOPSIS
Initialize and push Azure PLS Infrastructure project to GitHub

.DESCRIPTION
Automates git initialization, commits, and push to GitHub.
Handles both HTTPS and SSH authentication methods.

.PARAMETER GitHubUsername
Your GitHub username (e.g., 'johndoe')

.PARAMETER RepositoryName
Name of the GitHub repository (e.g., 'azure-pls-infrastructure')

.PARAMETER AuthMethod
Authentication method: 'https' or 'ssh' (default: 'https')

.PARAMETER CommitterName
Git user name (optional - uses git config if not provided)

.PARAMETER CommitterEmail
Git user email (optional - uses git config if not provided)

.PARAMETER SkipPush
If specified, initializes but doesn't push to GitHub

.EXAMPLE
.\init-github.ps1 `
  -GitHubUsername "johndoe" `
  -RepositoryName "azure-pls-infrastructure" `
  -CommitterName "John Doe" `
  -CommitterEmail "john@example.com"

.EXAMPLE
# Using SSH authentication
.\init-github.ps1 `
  -GitHubUsername "johndoe" `
  -RepositoryName "azure-pls-infrastructure" `
  -AuthMethod "ssh"

.NOTES
Requires: Git installed and GitHub account with repository created
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Your GitHub username")]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$true, HelpMessage="Repository name on GitHub")]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName,
    
    [ValidateSet("https", "ssh")]
    [string]$AuthMethod = "https",
    
    [string]$CommitterName,
    [string]$CommitterEmail,
    
    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'

# Color codes for output
$Success = 'Green'
$Warning = 'Yellow'
$Error_Color = 'Red'
$Info = 'Cyan'

function Write-Success { param([string[]]$Message); Write-Host "✓ $($Message -join ' ')" -ForegroundColor $Success }
function Write-Warning-Msg { param([string[]]$Message); Write-Host "⚠ $($Message -join ' ')" -ForegroundColor $Warning }
function Write-Error-Custom { param([string[]]$Message); Write-Host "❌ $($Message -join ' ')" -ForegroundColor $Error_Color }
function Write-Info { param([string[]]$Message); Write-Host "ℹ $($Message -join ' ')" -ForegroundColor $Info }

Write-Host "`n" + ("="*70) -ForegroundColor Cyan
Write-Host "   Azure PLS Infrastructure - GitHub Setup" -ForegroundColor Cyan
Write-Host ("="*70) -ForegroundColor Cyan

# Check if git is installed
Write-Info "Checking for Git installation..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "Git is not installed or not in PATH"
    Write-Host "Install Git: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

$gitVersion = git --version
Write-Success "Git found: $gitVersion"

# Check current location
$projectPath = Get-Location
Write-Info "Project path: $projectPath"

# Check if .git already exists
if (Test-Path ".git") {
    Write-Warning-Msg ".git directory already exists"
    $response = Read-Host "Continue anyway? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Configure git user if provided
if ($CommitterName -and $CommitterEmail) {
    Write-Info "Configuring git user..."
    git config user.name $CommitterName
    git config user.email $CommitterEmail
    Write-Success "Git user configured: $CommitterName <$CommitterEmail>"
} else {
    $configuredUser = git config user.name
    $configuredEmail = git config user.email
    if ($configuredUser -and $configuredEmail) {
        Write-Success "Using existing git config: $configuredUser <$configuredEmail>"
    } else {
        Write-Warning-Msg "Git user not configured globally. Set via:"
        Write-Host "  git config --global user.name 'Your Name'"
        Write-Host "  git config --global user.email 'your@email.com'"
    }
}

# Initialize git repository
Write-Info "`nInitializing git repository..."
if (Test-Path ".git") {
    Write-Host "Repository already initialized" -ForegroundColor Yellow
} else {
    git init
    Write-Success "Repository initialized"
}

# Add files
Write-Info "Adding files to staging..."
git add .

$stagedCount = (git diff --cached --name-only | Measure-Object -Line).Lines
Write-Success "Staged $stagedCount files"

# Show sample of staged files
$sampleFiles = git diff --cached --name-only | Select-Object -First 5
if ($sampleFiles) {
    Write-Host "Sample files:"
    $sampleFiles | ForEach-Object { Write-Host "  - $_" }
}

# Create initial commit
Write-Info "`nCreating initial commit..."
$commitMessage = @"
Initial commit: Azure PLS Infrastructure with 20 Private Endpoints

- Deploy Private Link Service (PLS) infrastructure
- Create 20 Private Endpoints connected to PLS
- Consumer VM for traffic generation and validation
- Log Analytics workspace for monitoring and diagnostics
- Metrics collection with interactive HTML dashboard
- Complete PowerShell automation and comprehensive documentation
- GitHub Actions CI/CD workflow for script validation
"@

git commit -m $commitMessage
Write-Success "Initial commit created"

# Setup remote
Write-Info "`nSetting up remote repository..."

if ($AuthMethod -eq "ssh") {
    $remoteUrl = "git@github.com:$GitHubUsername/$RepositoryName.git"
    Write-Info "Using SSH authentication"
} else {
    $remoteUrl = "https://github.com/$GitHubUsername/$RepositoryName.git"
    Write-Info "Using HTTPS authentication"
}

if (git config --get remote.origin.url) {
    Write-Warning-Msg "Remote origin already exists. Updating..."
    git remote set-url origin $remoteUrl
} else {
    git remote add origin $remoteUrl
}

Write-Success "Remote configured: $remoteUrl"

# Rename branch to main
Write-Info "`nSetting up main branch..."
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    git branch -M main
    Write-Success "Branch renamed to 'main'"
} else {
    Write-Success "Already on 'main' branch"
}

# Show repository status
Write-Host "`n" + ("-"*70)
git log --oneline -1
Write-Host ("-"*70)

# Prompt before pushing
if (-not $SkipPush) {
    Write-Info "`nRepository is ready to push. This will:"
    Write-Host "  1. Push all commits to: $remoteUrl"
    Write-Host "  2. May prompt for authentication (SSH key passphrase or GitHub token)"
    Write-Host ""
    
    $response = Read-Host "Continue with push? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Push skipped. To push later, run:" -ForegroundColor Yellow
        Write-Host "  git push -u origin main -v" -ForegroundColor Cyan
        exit 0
    }

    # Push to GitHub
    Write-Info "`nPushing to GitHub..."
    Write-Host "This may take a moment..." -ForegroundColor Yellow
    
    try {
        git push -u origin main -v
        Write-Success "Successfully pushed to GitHub!"
        Write-Host ""
        Write-Host "Repository URL:" -ForegroundColor Cyan
        Write-Host "  https://github.com/$GitHubUsername/$RepositoryName" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Add topics in GitHub (Settings → General)"
        Write-Host "  2. Enable GitHub Pages (Settings → Pages) - optional"
        Write-Host "  3. Create GitHub Releases (Releases tab)"
        Write-Host "  4. Setup branch protection (Settings → Branches) - optional"
    }
    catch {
        Write-Error-Custom "Push failed: $_"
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Check internet connection"
        Write-Host "  2. Verify GitHub credentials:"
        Write-Host "     - HTTPS: Use Personal Access Token (create at github.com/settings/tokens)"
        Write-Host "     - SSH: Ensure SSH key is configured (see GITHUB_SETUP.md)"
        Write-Host "  3. Try manual push:"
        Write-Host "     git push -u origin main -v"
        exit 1
    }
} else {
    Write-Success "Repository initialized (push skipped)"
    Write-Host ""
    Write-Host "To push when ready, run:" -ForegroundColor Yellow
    Write-Host "  git push -u origin main" -ForegroundColor Cyan
}

Write-Host "`n" + ("="*70) -ForegroundColor Cyan
Write-Host "   Setup Complete!" -ForegroundColor Cyan
Write-Host ("="*70) -ForegroundColor Cyan
Write-Host ""

exit 0
