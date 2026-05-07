# SQL Server Multi-Region with Private Link Service — Snowflake Integration

Multi-region SQL Server HA/DR architecture with Private Link Service exposure for Snowflake connectivity.

## Architecture

- **Primary Region (East US 2)**: 2 SQL Server VMs (zones 1+2) behind Standard ILB + Private Link Service
- **Secondary Region (West US 3)**: 2 SQL Server VMs (zones 2+3) behind Standard ILB + Private Link Service
- **Cross-Region**: Global VNet Peering for WSFC/AG replication, Cloud Witness in East US
- **Snowflake**: 4 Private Endpoints covering all failover combinations

## Failover Scenarios

| Scenario | Snowflake Region | SQL Region | Path |
|----------|-----------------|------------|------|
| Normal | East US 2 | East US 2 | PE → PLS East US 2 → ILB → SQL VMs |
| Snowflake failover | West US 3 | East US 2 | PE (West US 3) → PLS East US 2 |
| SQL failover | East US 2 | West US 3 | PE (East US 2) → PLS West US 3 |
| Both failover | West US 3 | West US 3 | PE → PLS West US 3 → ILB → SQL VMs |

## Deployment

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan -var="admin_password=YOUR_PASSWORD"
terraform apply -var="admin_password=YOUR_PASSWORD"
```

## Post-Deployment

1. Configure WSFC cluster and SQL Always On Availability Groups
2. Provision Snowflake Private Endpoints using `SYSTEM$PROVISION_PRIVATELINK_ENDPOINT`
3. Approve PE connections in Azure Portal

## AdventureWorks Database

The AdventureWorks2022 sample database is configured on all 4 SQL Server VMs.
