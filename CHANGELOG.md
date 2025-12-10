# Changelog

All notable changes to the Azure PLS Infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-09

### Added

- Initial release of Azure PLS Infrastructure project
- Complete PowerShell-based deployment automation for:
  - Private Link Service (PLS) infrastructure
  - 20 Private Endpoints (PEs)
  - Consumer VM for traffic generation
  - Log Analytics workspace for monitoring
  
- **Scripts**:
  - `deploy.ps1`: Main infrastructure deployment script
  - `generate-traffic.ps1`: Test traffic generation tool
  - `get-pls-pe-metrics-dashboard.ps1`: Advanced metrics collection with HTML dashboard
  - `collect-metrics.ps1`: Basic metrics collection
  - `create-pe-graph.ps1`: Visualization tool for PE metrics

- **Documentation**:
  - Comprehensive README with architecture overview
  - PREREQUISITES.md with setup and troubleshooting guides
  - CONTRIBUTING.md for contributor guidelines
  - LICENSE (MIT)
  - .gitignore for GitHub

- **Features**:
  - Automatic resource group creation
  - Pre-configured networking (two VNets: 10.0.0.0/16 and 10.1.0.0/16)
  - Standard Load Balancer with health probes
  - Auto-approved Private Link Service
  - 20 Private Endpoints connected to PLS
  - Ubuntu 18.04 LTS consumer VM
  - Log Analytics workspace for diagnostics
  - CSV export of metrics
  - Interactive HTML dashboard with visual metrics
  - Support for multiple aggregation methods (sum, avg, max, min)
  - Flexible time range options (absolute, relative, lookback hours)

### Documentation

- Added comprehensive README with quick start guide
- Added PREREQUISITES.md with detailed setup instructions
- Added CONTRIBUTING.md with contribution guidelines
- Added architecture diagrams and examples
- Added security considerations and cost management tips

### Security

- MIT License with disclaimer
- .gitignore to prevent credential leaks
- Guidance on securing sensitive data
- Default NSG rules for network segmentation
- Auto-approved PLS (changeable for production)

## [Unreleased]

### Planned Features

- [ ] Azure DevOps pipeline templates for CI/CD
- [ ] Terraform alternative to PowerShell/Bicep
- [ ] ARM template versions of Bicep templates
- [ ] Python-based metrics collection tool
- [ ] Integration with Azure Monitor alerts
- [ ] Web-based dashboard (vs. HTML export)
- [ ] Multi-region deployment support
- [ ] Automated cleanup script
- [ ] Performance benchmarking tools
- [ ] Cost analysis and reporting

### Known Issues

- HTML dashboard requires manual browser refresh (no real-time updates)
- Metrics collection requires 10-15 minutes after deployment
- Limited support for non-Windows environments (PowerShell only)

---

## Version History

### 1.0.0 (Current)

**Release Date**: December 9, 2025

**Status**: ✅ Production Ready

**Key Components**:
- Deployment: PowerShell + Bicep
- Metrics: Azure Monitor API
- Visualization: HTML + CSS
- Infrastructure: Azure Resource Manager

**Testing**:
- Verified on PowerShell 5.1 and 7.x
- Tested with Azure PowerShell 9.x+
- Validated on Windows 10/11 and Windows Server 2019+
- Confirmed with multiple Azure regions

**Compatibility**:
- ✅ PowerShell 5.1+
- ✅ Azure PowerShell 9.x+
- ✅ Windows 10/11, Windows Server 2016+
- ✅ Azure CLI 2.x+ (optional)

---

## How to Report Issues

When reporting issues, please provide:

1. Script version and execution command
2. PowerShell version: `$PSVersionTable.PSVersion`
3. Azure PowerShell version: `Get-Module Az | Select-Object Version`
4. Error message and stack trace
5. Steps to reproduce
6. Environment details (OS, region, subscription type)

## Upgrade Instructions

### From 0.x to 1.0

1. Backup your current scripts
2. Clone the new version
3. Update configuration variables in `deploy.ps1`
4. Re-run deployment or manual resource updates
5. Test metrics collection with new dashboard script

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to suggest features
- How to report bugs
- How to submit pull requests
- Coding standards and guidelines

## Roadmap

### Q1 2026
- [ ] Terraform provider alternative
- [ ] Python SDK wrapper for metrics collection
- [ ] Enhanced error recovery in deployment scripts

### Q2 2026
- [ ] Multi-region deployment automation
- [ ] Azure DevOps/GitHub Actions CI/CD templates
- [ ] Performance baseline testing tools

### Q3 2026
- [ ] Web-based real-time dashboard
- [ ] Cost analysis and reporting module
- [ ] Automated resource cleanup and archival

### Q4 2026
- [ ] Enterprise-grade monitoring integration
- [ ] Multi-subscription management
- [ ] Advanced traffic simulation scenarios

---

## Support

- **Documentation**: See README.md and PREREQUISITES.md
- **Issues**: GitHub Issues (bug reports, feature requests)
- **Discussions**: GitHub Discussions (questions, ideas)
- **Contact**: [Maintainer contact information]

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

**Last Updated**: December 9, 2025  
**Maintained By**: [Your Name/Organization]
