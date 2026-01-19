.PHONY: help init plan apply deploy validate destroy clean format lint

# Default target
help:
	@echo "Azure Hub-Spoke Network - Makefile Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  make init      - Initialize Terraform"
	@echo "  make plan      - Create Terraform plan"
	@echo "  make apply     - Apply Terraform changes"
	@echo "  make deploy    - Full deployment (init + plan + apply)"
	@echo "  make validate  - Validate deployment"
	@echo "  make destroy   - Destroy all resources"
	@echo "  make clean     - Clean Terraform files"
	@echo "  make format    - Format Terraform files"
	@echo "  make lint      - Lint Terraform files"
	@echo ""

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform init

# Create plan
plan:
	@echo "Creating Terraform plan..."
	terraform plan -out=tfplan

# Apply changes
apply:
	@echo "Applying Terraform plan..."
	terraform apply tfplan
	@rm -f tfplan

# Full deployment
deploy:
	@echo "Starting full deployment..."
	@./deploy.sh

# Validate deployment
validate:
	@echo "Validating deployment..."
	@./validate.sh

# Destroy resources
destroy:
	@echo "Destroying resources..."
	@./cleanup.sh

# Clean Terraform files
clean:
	@echo "Cleaning Terraform files..."
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
	@rm -f tfplan
	@rm -f terraform.tfstate*
	@echo "Clean complete!"

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive
	@echo "Format complete!"

# Lint Terraform files
lint:
	@echo "Linting Terraform files..."
	terraform fmt -check -recursive
	terraform validate
	@echo "Lint complete!"

# Show outputs
outputs:
	@echo "Terraform outputs:"
	@terraform output

# Validate Terraform configuration
check:
	@echo "Checking Terraform configuration..."
	terraform fmt -check -recursive
	terraform validate
	@echo "Configuration is valid!"
