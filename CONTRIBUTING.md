# Contributing to Azure PLS Infrastructure

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## 📋 Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## 🤝 How to Contribute

### Reporting Bugs

Before creating a bug report, please check the issue tracker to avoid duplicates.

**When reporting a bug, include:**

```
**Description**: Clear description of the issue

**Steps to Reproduce**:
1. [First step]
2. [Second step]
3. [...]

**Expected Behavior**: What should happen

**Actual Behavior**: What actually happened

**Environment**:
- PowerShell Version: [output of $PSVersionTable.PSVersion]
- Azure PowerShell Version: [output of Get-Module Az | Select-Object Version]
- OS: Windows 10/11/Server
- Region: [Azure region used]

**Error Messages**: [Include full error stack trace]

**Logs**: [Attach any relevant logs]
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues.

**Include:**

```
**Description**: What enhancement would be useful?

**Use Case**: Why do you need this enhancement?

**Current Behavior**: How is it currently done?

**Proposed Solution**: How should it work?

**Alternatives**: Other approaches you considered

**Impact**: How many users would benefit?
```

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/azure-pls-infrastructure.git
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow coding standards (see below)
   - Update documentation if needed
   - Add comments for complex logic
   - Test thoroughly

4. **Commit with clear messages**
   ```bash
   git commit -m "Add: Clear description of changes"
   ```

   **Commit message format:**
   ```
   [Type]: [Brief description]
   
   [Longer explanation if needed]
   ```

   Types:
   - `Add`: New feature
   - `Fix`: Bug fix
   - `Doc`: Documentation update
   - `Refactor`: Code restructuring
   - `Test`: Test additions/modifications
   - `Perf`: Performance improvements
   - `Style`: Code style changes

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Clear title and description
   - Reference any related issues
   - Explain the changes and why they're needed
   - Include screenshots for UI changes if applicable

## 📝 Coding Standards

### PowerShell Scripts

1. **File Structure**
   ```powershell
   <#
   .SYNOPSIS
   Brief one-line description
   
   .DESCRIPTION
   Detailed description of what the script does
   
   .PARAMETER ParamName
   Description of the parameter
   
   .EXAMPLE
   Example of how to use the script
   
   .NOTES
   Author: Name
   Date: YYYY-MM-DD
   #>
   
   param (
       [Parameter(Mandatory=$true, HelpMessage="Description")]
       [ValidateNotNullOrEmpty()]
       [string]$ParameterName
   )
   ```

2. **Naming Conventions**
   - Functions: `PascalCase` (e.g., `Get-ResourceMetrics`)
   - Variables: `$camelCase` (e.g., `$resourceId`)
   - Constants: `$UPPERCASE` (e.g., `$MAX_RETRIES`)
   - Files: `lowercase-with-hyphens.ps1`

3. **Error Handling**
   ```powershell
   $ErrorActionPreference = 'Stop'
   
   try {
       # Your code
   }
   catch {
       Write-Error "Descriptive error message: $_"
       exit 1
   }
   finally {
       # Cleanup code
   }
   ```

4. **Comments**
   ```powershell
   # Single line comments for simple statements
   
   <#
   Multi-line comments for complex logic blocks.
   Explain the 'why' not the 'what'.
   #>
   ```

5. **Format and Indentation**
   - Use 4 spaces (never tabs)
   - Maximum line length: 120 characters
   - One blank line between functions
   - Two blank lines between sections

### Bicep Templates

1. **File Structure**
   ```bicep
   // Metadata
   metadata {
     description: 'Template description'
     version: '1.0.0'
   }
   
   // Parameters
   param location string = resourceGroup().location
   
   // Variables
   var resourceName = 'pls-${uniqueString(resourceGroup().id)}'
   
   // Resources
   resource resourceSymbolicName 'Microsoft.Network/virtualNetworks@2021-02-01' = {
     // ...
   }
   
   // Outputs
   output resourceId string = resource.id
   ```

2. **Naming Conventions**
   - Variables: `camelCase`
   - Parameters: `camelCase`
   - Symbolic names: `camelCase`
   - File names: `descriptive-name.bicep`

3. **Comments**
   ```bicep
   // Single line comment
   
   /*
   Multi-line comment
   for complex sections
   */
   ```

### Markdown Documentation

1. **Structure**
   - Use proper heading hierarchy (# → ##)
   - Keep lines under 120 characters
   - Use code blocks with language specification
   - Include table of contents for long documents

2. **Code Examples**
   ```markdown
   ### Example
   
   ```powershell
   # Clear code example
   $subscription = Get-AzSubscription
   ```
   ```

3. **Links and References**
   - Use meaningful link text
   - Link to official documentation when possible
   - Keep external links current

## 🧪 Testing

Before submitting a PR:

1. **Syntax Check**
   ```powershell
   # Test script syntax
   Test-Path -Path ./scripts/your-script.ps1
   ```

2. **Manual Testing**
   - Test on your local environment
   - Verify with different parameter combinations
   - Check error handling
   - Validate Azure resource creation

3. **Documentation Testing**
   - Verify all examples work
   - Check all links are valid
   - Ensure formatting renders correctly

## 📋 Pull Request Checklist

Before submitting, ensure:

- [ ] Code follows project style guidelines
- [ ] Commit messages are clear and descriptive
- [ ] Comments and docstrings are present
- [ ] Documentation is updated
- [ ] No sensitive data (keys, passwords, IDs) is included
- [ ] Changes are tested
- [ ] PR description explains the changes
- [ ] Related issues are referenced

## 🔄 Review Process

1. A maintainer will review your PR within 3-5 business days
2. Feedback and suggestions will be provided
3. Make requested changes in new commits
4. Once approved, your PR will be merged
5. Your contribution will be acknowledged

## 📖 Documentation Standards

When adding features or scripts:

1. **Update README.md** with usage examples
2. **Add docstring/comments** to scripts
3. **Create EXAMPLES.md** for complex features
4. **Update CHANGELOG.md** (if present)
5. **Add to troubleshooting guide** if applicable

## 🔐 Security Guidelines

1. **Never commit**:
   - Passwords or secrets
   - API keys or tokens
   - Subscription IDs in examples
   - Private IP addresses in documentation

2. **Use**:
   - Environment variables for sensitive data
   - `.gitignore` for local files
   - Comments like `# Replace with your value`

3. **Code Review**:
   - All code is reviewed for security
   - Vulnerabilities must be reported privately
   - Follow responsible disclosure practices

## 💡 Development Tips

### Local Testing

```powershell
# Test script syntax
Get-Content .\scripts\your-script.ps1 | Out-Null

# Lint with PSScriptAnalyzer (recommended)
Install-Module PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path .\scripts\your-script.ps1

# Test Bicep templates
az bicep build --file ./infrastructure/template.bicep
```

### Setting Up Dev Environment

```powershell
# Clone and navigate
git clone https://github.com/yourusername/azure-pls-infrastructure.git
cd azure-pls-infrastructure

# Install dependencies
Install-Module Az -Force -AllowClobber
Install-Module PSScriptAnalyzer -Force

# Create a feature branch
git checkout -b feature/your-feature
```

## 📞 Need Help?

- **Questions?** Open a discussion in GitHub Discussions
- **Found a bug?** Open an issue with the bug label
- **Have an idea?** Open an issue with the enhancement label
- **Want to chat?** Reach out to the maintainers

## 🎉 Recognition

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- GitHub contributors page
- Release notes for major contributions

Thank you for contributing! 🙏
