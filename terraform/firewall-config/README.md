# Firewall Configuration Directory

This directory contains configuration files specifically for Azure Firewall rules that can be applied to the Virtual WAN core firewall.

## Directory Structure

```
firewall-config/
├── firewall-rules.yaml    # Sample configuration file with comprehensive firewall rules
└── README.md             # This documentation file
```

## Purpose

This directory is separate from the main `config/` directory to prevent the Virtual WAN workflow from processing firewall-specific configurations. The firewall rules are managed independently and applied through the firewall rules module.

## Configuration Structure

The YAML configuration file supports three types of rule collections:

### 1. Network Rule Collections

Network rules control traffic based on IP addresses, ports, and protocols.

```yaml
network_rule_collections:
  - name: "allow-internet-access"
    priority: 100
    action: "Allow"
    rules:
      - name: "allow-https"
        protocols:
          - type: "Https"
        source_addresses: ["*"]
        destination_addresses: ["*"]
        destination_ports: ["443"]
        description: "Allow HTTPS traffic to internet"
```

### 2. Application Rule Collections

Application rules control traffic based on FQDNs (Fully Qualified Domain Names).

```yaml
application_rule_collections:
  - name: "allow-azure-services"
    priority: 100
    action: "Allow"
    rules:
      - name: "allow-azure-platform"
        protocols:
          - port: 443
            type: "Https"
        source_addresses: ["*"]
        destination_fqdns: 
          - "*.azure.com"
          - "*.microsoft.com"
        description: "Allow access to Azure platform services"
```

### 3. NAT Rule Collections

NAT rules provide inbound access to internal resources.

```yaml
nat_rule_collections:
  - name: "inbound-nat-rules"
    priority: 100
    action: "Dnat"
    rules:
      - name: "rdp-to-jumpbox"
        protocols:
          - type: "Tcp"
        source_addresses: ["*"]
        destination_addresses: ["${firewall_public_ip}"]
        destination_ports: ["3389"]
        translated_address: "10.0.3.10"
        translated_port: "3389"
        description: "RDP access to jumpbox server"
```

## Supported Protocols

### Network Rules
- `Http` - HTTP traffic
- `Https` - HTTPS traffic
- `Tcp` - TCP traffic
- `Udp` - UDP traffic
- `Icmp` - ICMP traffic

### Application Rules
- `Http` - HTTP traffic
- `Https` - HTTPS traffic

## Variables

The configuration supports variable substitution using `${variable_name}` syntax:

- `${environment}` - Environment name (dev, test, prod)
- `${location}` - Azure region
- `${firewall_public_ip}` - Public IP address of the firewall

## Usage

1. **Customize the configuration**: Edit `firewall-rules.yaml` to match your security requirements
2. **Add your rules**: Add network, application, or NAT rules as needed
3. **Set priorities**: Ensure rule collection priorities are set appropriately (lower numbers = higher priority)
4. **Deploy**: The Terraform module will automatically read and apply the configuration

## Integration with Virtual WAN Core

The firewall rules are applied through the `firewall_rules` module in `main-vwan-core.tf`:

```hcl
module "firewall_rules" {
  source = "./modules/firewall-rules"
  
  config_file_path   = "${path.module}/firewall-config/firewall-rules.yaml"
  firewall_policy_id = azurerm_firewall_policy.vwan.id
  tags               = var.tags
}
```

## Best Practices

1. **Start with deny-all**: Begin with restrictive rules and add allowances as needed
2. **Use specific addresses**: Avoid using `*` for source/destination addresses when possible
3. **Document rules**: Always include descriptions for your rules
4. **Test thoroughly**: Test firewall rules in a non-production environment first
5. **Monitor logs**: Enable Azure Firewall logging to monitor traffic patterns

## Example Customizations

### Adding a new service
```yaml
- name: "allow-custom-service"
  protocols:
    - port: 443
      type: "Https"
  source_addresses: ["10.0.0.0/8"]
  destination_fqdns: ["api.myservice.com"]
  description: "Allow access to custom API service"
```

### Restricting access to specific IP ranges
```yaml
- name: "restrict-admin-access"
  protocols:
    - type: "Tcp"
  source_addresses: ["203.0.113.0/24", "198.51.100.0/24"]
  destination_addresses: ["10.0.3.0/24"]
  destination_ports: ["22", "3389"]
  description: "Restrict admin access to specific IP ranges"
```

## Troubleshooting

### Common Issues

1. **Rule conflicts**: Check rule collection priorities
2. **FQDN resolution**: Ensure DNS is properly configured
3. **Port conflicts**: Verify no overlapping port configurations
4. **IP address ranges**: Check for overlapping or invalid IP ranges

### Validation

The Terraform module will validate the YAML structure and provide error messages for:
- Invalid protocol types
- Missing required fields
- Invalid IP address formats
- Duplicate rule names

## Security Considerations

1. **Principle of least privilege**: Only allow necessary traffic
2. **Regular reviews**: Periodically review and update firewall rules
3. **Logging**: Enable comprehensive logging for audit purposes
4. **Monitoring**: Set up alerts for blocked traffic patterns
5. **Documentation**: Maintain up-to-date documentation of all rules

## Workflow Separation

This directory is intentionally separate from the main `config/` directory to:
- Prevent Virtual WAN workflows from processing firewall configurations
- Allow independent management of firewall rules
- Maintain clear separation of concerns
- Enable different deployment schedules for firewall rules vs. Virtual WAN resources 