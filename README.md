# Enterprise Hub-Spoke Network with Secure Access

## Project Overview:

This project is to implement a production-ready hub-spoke network topology in Azure with centralized security controls, private connectivity, and secure remote access. It will help you understand how the traffic flows between networks and how the overall infra can be secured.



---

## Architecture Overview:

![Architecture Overview](./docs/Architecure%20Diagram.png)

---

Please refer the [deployment guide](./docs/deployment-guide.md) for the related deployment and testing scenarios.

Also refer the the learning.md file to know some important concepts used in this project.

---

## Key Concepts

### Hub-Spoke Topology Benefits

1. **Centralized Security**: All traffic flows through the hub firewall
2. **Cost Optimization**: Shared services in hub reduce duplication
3. **Scalability**: Easy to add new spokes
4. **Isolation**: Spokes are isolated from each other by default

### Traffic Flow

1. **Spoke-to-Internet**: Spoke VM → Hub Firewall → Internet
2. **Spoke-to-Spoke**: Spoke A VM → Hub Firewall → Spoke B VM
3. **On-premises-to-Azure**: On-prem → VPN Gateway (Hub) → Spokes
4. **Admin Access**: User → Azure Bastion (Hub) → Spoke VMs (SSH)

### Test VMs

The project includes an optional VM module to deploy Ubuntu test VMs in each spoke:

| Spoke | VM Name | Private IP | Purpose |
|-------|---------|------------|----------|
| web | vm-hubspoke-dev-web-XXXX | 10.1.1.4 | Test web tier connectivity |
| data | vm-hubspoke-dev-data-XXXX | 10.2.1.4 | Test data tier connectivity |
| mgmt | vm-hubspoke-dev-mgmt-XXXX | 10.3.1.4 | Test management connectivity |

**Pre-installed tools:** `curl`, `wget`, `traceroute`, `nslookup`, `tcpdump`, `nmap`

---

## Security Best Practices

1. **Zero Trust**: All traffic flows through firewall
2. **Least Privilege**: NSGs with minimal required rules
3. **No Public IPs**: VMs accessed only via Bastion
4. **Audit Logging**: All firewall logs sent to Log Analytics
5. **Private Endpoints**: No public exposure for PaaS services

---

## Learning Resources

- [Azure Hub-Spoke Reference Architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://learn.microsoft.com/azure/firewall/)
- [Azure Bastion Documentation](https://learn.microsoft.com/azure/bastion/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---