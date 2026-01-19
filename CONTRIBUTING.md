# Contributing to Azure Hub-Spoke Network

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check if the issue already exists in the [Issues](https://github.com/sagpat/azure-hub-spoke-network/issues) section
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Terraform version and Azure CLI version
   - Relevant logs or error messages

### Submitting Changes

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/azure-hub-spoke-network.git
   cd azure-hub-spoke-network
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes**
   - Follow the coding standards below
   - Test your changes thoroughly
   - Update documentation as needed

4. **Validate your changes**
   ```bash
   # Format Terraform code
   terraform fmt -recursive

   # Validate configuration
   terraform validate

   # Check for security issues
   terraform plan
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```

6. **Push and create a Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```
   
   Then create a Pull Request on GitHub.

## Coding Standards

### Terraform Code Style

1. **Formatting**
   - Use `terraform fmt` to format all `.tf` files
   - Use 2 spaces for indentation
   - Keep line length under 120 characters

2. **Naming Conventions**
   - Resources: Use lowercase with hyphens (e.g., `azurerm_virtual_network.hub`)
   - Variables: Use snake_case (e.g., `hub_vnet_address_space`)
   - Use Azure naming conventions (e.g., `vnet-prod-hub`, `nsg-prod-workload`)

3. **Resource Naming Pattern**
   ```
   {resource-type}-{environment}-{purpose}
   
   Examples:
   - vnet-prod-hub
   - nsg-dev-workload
   - afw-prod-hub
   ```

4. **Code Organization**
   - Group related resources together
   - Add comments to explain complex configurations
   - Use descriptive resource names

5. **Variables**
   - Provide descriptions for all variables
   - Set sensible defaults where appropriate
   - Document expected values in comments

6. **Outputs**
   - Provide outputs for important resource IDs and properties
   - Include descriptions for all outputs

### Documentation

1. **README Updates**
   - Update README.md if adding new features
   - Include examples and use cases
   - Update configuration tables

2. **Code Comments**
   - Comment complex logic
   - Explain why, not what (code should be self-explanatory)
   - Use clear, concise language

3. **Documentation Files**
   - Update architecture.md for architectural changes
   - Update traffic-flows.md for networking changes
   - Keep documentation in sync with code

### Shell Scripts

1. **Style**
   - Use bash shebang: `#!/bin/bash`
   - Add `set -e` for error handling
   - Include comments explaining each section

2. **Error Handling**
   - Check for prerequisites
   - Validate inputs
   - Provide helpful error messages

## Testing Guidelines

### Before Submitting

1. **Terraform Validation**
   ```bash
   terraform init
   terraform validate
   terraform fmt -check
   ```

2. **Deploy to Test Environment**
   ```bash
   # Deploy to a test subscription
   terraform plan
   terraform apply
   ```

3. **Validate Deployment**
   ```bash
   ./validate.sh
   ```

4. **Test Functionality**
   - Verify VNet peering is connected
   - Test firewall rules
   - Check NSG rules
   - Verify logging is working

5. **Cleanup**
   ```bash
   terraform destroy
   ```

### What to Test

- [ ] Terraform init succeeds
- [ ] Terraform validate passes
- [ ] Terraform plan completes without errors
- [ ] Terraform apply succeeds
- [ ] All resources are created correctly
- [ ] VNet peering is connected
- [ ] Firewall is accessible
- [ ] Bastion can connect to VMs
- [ ] Logging is configured
- [ ] Documentation is updated

## Types of Contributions

### Adding New Features

Examples:
- Additional spoke networks
- New Azure services (e.g., Application Gateway, Azure Front Door)
- Enhanced monitoring
- Additional security features

Guidelines:
- Discuss major changes in an issue first
- Maintain backward compatibility
- Update documentation
- Add examples

### Bug Fixes

- Describe the bug and the fix in the PR
- Include steps to reproduce
- Add tests if applicable

### Documentation

- Fix typos and improve clarity
- Add examples and diagrams
- Update for new Azure features
- Translate to other languages (future)

### Security Improvements

- Report security issues privately first
- Follow responsible disclosure
- Document security best practices

## Pull Request Process

1. **Before Submitting**
   - Ensure all tests pass
   - Update documentation
   - Follow coding standards
   - Squash commits if needed

2. **PR Description**
   - Describe what changed and why
   - Reference related issues
   - Include testing performed
   - Note any breaking changes

3. **Review Process**
   - Maintainers will review your PR
   - Address feedback promptly
   - Keep discussions professional and constructive

4. **After Merge**
   - Your changes will be in the next release
   - You'll be credited in release notes

## Security Vulnerabilities

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. Email the maintainers privately
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Public or private harassment
- Publishing others' private information

## Questions?

- Open an issue with the "question" label
- Reach out to maintainers
- Check existing issues and documentation

## Recognition

Contributors will be:
- Listed in release notes
- Credited in the README (for significant contributions)
- Eligible to become maintainers (for ongoing contributions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort! 🎉
