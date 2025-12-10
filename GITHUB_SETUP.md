# Initialize Local Git Repository and Push to GitHub

This guide walks you through initializing git and pushing your Azure PLS Infrastructure project to GitHub.

## Prerequisites

1. **Git installed** on your machine
   ```powershell
   # Check if git is installed
   git --version
   
   # If not installed, install via winget
   winget install Git.Git
   ```

2. **GitHub account** and SSH/HTTPS authentication configured
   - [Setup GitHub SSH Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
   - Or use [GitHub CLI](https://cli.github.com/)

3. **Repository created** on GitHub
   - Go to https://github.com/new
   - Create a new repository (e.g., `azure-pls-infrastructure`)
   - Do NOT initialize with README (we have one already)

## Step-by-Step Instructions

### 1. Navigate to Project Directory

```powershell
cd "c:\Users\msrini\OneDrive - Microsoft\Desktop\PLS"
```

### 2. Initialize Git Repository

```powershell
# Initialize git
git init

# Configure git user (if not already configured globally)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Or use global config
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. Add All Files to Git

```powershell
# Add all files
git add .

# Verify files to be committed
git status

# Show what's staged
git diff --cached --name-only
```

### 4. Create Initial Commit

```powershell
git commit -m "Initial commit: Azure PLS Infrastructure with 20 Private Endpoints

- Deploy Private Link Service (PLS) infrastructure
- Create 20 Private Endpoints connected to PLS
- Consumer VM for traffic generation
- Log Analytics workspace for monitoring
- Metrics collection with interactive HTML dashboard
- Complete PowerShell automation and documentation"
```

### 5. Add Remote Repository

**Using HTTPS (recommended for beginners):**
```powershell
git remote add origin https://github.com/yourusername/azure-pls-infrastructure.git
```

**Using SSH (if configured):**
```powershell
git remote add origin git@github.com:yourusername/azure-pls-infrastructure.git
```

### 6. Rename Default Branch (Optional)

```powershell
# Rename to 'main' (GitHub's default)
git branch -M main
```

### 7. Push to GitHub

```powershell
# For the first time
git push -u origin main

# Or with verbose output
git push -u origin main -v
```

### 8. Verify on GitHub

1. Go to https://github.com/yourusername/azure-pls-infrastructure
2. Verify all files are present
3. Check that the README is displayed

## Complete Automation Script

Here's a PowerShell script to automate everything:

```powershell
# save as: init-github.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$RepositoryName,
    
    [Parameter(Mandatory=$true)]
    [string]$AuthMethod = "https", # or "ssh"
    
    [string]$CommitterName,
    [string]$CommitterEmail
)

# Get current directory
$projectPath = Get-Location
Write-Host "Initializing git in: $projectPath" -ForegroundColor Cyan

# Verify .git doesn't exist
if (Test-Path ".git") {
    Write-Host "❌ Git repository already exists. Run 'git status' to check." -ForegroundColor Red
    exit 1
}

# Initialize repository
Write-Host "`n🔧 Initializing git repository..." -ForegroundColor Yellow
git init

# Configure user (if provided)
if ($CommitterName) {
    git config user.name $CommitterName
    git config user.email $CommitterEmail
    Write-Host "✓ Git user configured: $CommitterName <$CommitterEmail>" -ForegroundColor Green
}

# Add files
Write-Host "`n📁 Adding files to staging..." -ForegroundColor Yellow
git add .

# Show what's staged
$stagedFiles = git diff --cached --name-only
Write-Host "Staged files: $($stagedFiles.Count) files"
Write-Host $stagedFiles | Select-Object -First 5
Write-Host "..."

# Create initial commit
Write-Host "`n💾 Creating initial commit..." -ForegroundColor Yellow
$commitMessage = @"
Initial commit: Azure PLS Infrastructure with 20 Private Endpoints

- Deploy Private Link Service (PLS) infrastructure
- Create 20 Private Endpoints connected to PLS
- Consumer VM for traffic generation
- Log Analytics workspace for monitoring
- Metrics collection with interactive HTML dashboard
- Complete PowerShell automation and documentation
"@

git commit -m $commitMessage

# Set remote
Write-Host "`n🔗 Setting up remote repository..." -ForegroundColor Yellow

if ($AuthMethod -eq "ssh") {
    $remoteUrl = "git@github.com:$GitHubUsername/$RepositoryName.git"
} else {
    $remoteUrl = "https://github.com/$GitHubUsername/$RepositoryName.git"
}

git remote add origin $remoteUrl
Write-Host "✓ Remote added: $remoteUrl" -ForegroundColor Green

# Rename branch
Write-Host "`n🌿 Renaming branch to 'main'..." -ForegroundColor Yellow
git branch -M main

# Push to GitHub
Write-Host "`n🚀 Pushing to GitHub..." -ForegroundColor Yellow
Write-Host "This may prompt for authentication (GitHub tokens or SSH passphrase)" -ForegroundColor Cyan

git push -u origin main -v

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "Repository URL: https://github.com/$GitHubUsername/$RepositoryName" -ForegroundColor Cyan
} else {
    Write-Host "`n❌ Push failed. Check the error message above." -ForegroundColor Red
    exit 1
}
```

**Usage:**

```powershell
# Run the script
.\init-github.ps1 `
  -GitHubUsername "yourusername" `
  -RepositoryName "azure-pls-infrastructure" `
  -AuthMethod "https" `
  -CommitterName "Your Name" `
  -CommitterEmail "your.email@example.com"
```

## Troubleshooting

### "fatal: A git repository already exists"

```powershell
# Remove existing git
Remove-Item -Path ".git" -Recurse -Force

# Then run git init again
git init
```

### "fatal: authentication failed"

**For HTTPS:**
```powershell
# Use Personal Access Token (PAT) instead of password
# Create PAT at: https://github.com/settings/tokens

# When prompted, use:
# Username: your-github-username
# Password: your-personal-access-token (not your actual password)
```

**For SSH:**
```powershell
# Setup SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
$env:GIT_SSH_COMMAND="ssh -i $env:USERPROFILE\.ssh\id_ed25519"

# Add public key to GitHub: https://github.com/settings/keys
```

### "remote origin already exists"

```powershell
# Remove existing remote
git remote remove origin

# Add new remote
git remote add origin https://github.com/yourusername/repository.git
```

### Changes not pushing

```powershell
# Check status
git status

# Pull latest if behind
git pull origin main

# Try push again
git push origin main
```

## Next Steps

After pushing to GitHub:

1. **Setup GitHub Pages** (optional - for documentation site)
   - Settings → Pages → Source: main branch /docs folder

2. **Enable GitHub Actions**
   - Go to Actions tab
   - Workflows will run automatically on push

3. **Create GitHub Releases** (for tagged versions)
   ```powershell
   git tag -a v1.0.0 -m "Version 1.0.0 release"
   git push origin v1.0.0
   ```

4. **Add Topics** to your repository
   - Go to Settings → General
   - Add topics: `azure`, `powershell`, `infrastructure-as-code`, `private-link`

5. **Setup Branch Protection** (optional but recommended)
   - Settings → Branches → Add rule
   - Require reviews before merging
   - Require status checks to pass

## Additional Resources

- [GitHub Docs: Adding an existing project to GitHub](https://docs.github.com/en/get-started/importing-your-projects-to-github/importing-source-code-to-github/adding-an-existing-project-to-github-using-the-command-line)
- [GitHub CLI Documentation](https://cli.github.com/manual)
- [Git Documentation](https://git-scm.com/doc)

---

**Need help?** Check the CONTRIBUTING.md file for guidelines on repository management.
