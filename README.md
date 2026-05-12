# SQL Server Multi-Region with Private Link Service — Snowflake Integration

Multi-region SQL Server HA/DR architecture with Private Link Service exposure for Snowflake connectivity and automated cross-region failover.

## Architecture

See [docs/architecture-diagram.md](docs/architecture-diagram.md) for full Mermaid diagrams.

- **Primary Region (East US 2)**: 2 SQL Server VMs (zones 1+2) behind Standard ILB + Private Link Service
- **Secondary Region (West US 3)**: 2 SQL Server VMs (zones 2+3) behind Standard ILB + Private Link Service
- **Cross-Region**: Global VNet Peering for WSFC/AG replication, Cloud Witness in East US
- **Snowflake**: 4 Private Endpoints covering all failover combinations
- **Automated Failover**: Azure Function monitors ILB health, switches Snowflake network rules via SQL API

## Failover Scenarios

| Scenario | Snowflake Region | SQL Region | Path |
|----------|-----------------|------------|------|
| Normal | East US 2 | East US 2 | PE → PLS East US 2 → ILB → SQL VMs |
| Snowflake failover | West US 3 | East US 2 | PE (West US 3) → PLS East US 2 |
| SQL failover | East US 2 | West US 3 | PE (East US 2) → PLS West US 3 |
| Both failover | West US 3 | West US 3 | PE → PLS West US 3 → ILB → SQL VMs |

## Automated Failover

The `failover-function/` directory contains a Python Azure Function that:
1. Receives Azure Monitor alerts when ILB health degrades
2. Checks failover state and cooldown (Table Storage)
3. Authenticates to Snowflake via JWT keypair auth (Key Vault)
4. Executes `ALTER NETWORK RULE` via Snowflake SQL API to switch traffic
5. Supports manual failover via `/api/failover/switch` endpoint
6. Exposes status via `/api/failover/status` endpoint

### Endpoints
- `POST /api/failover` — Alert-triggered automatic failover
- `POST /api/failover/switch` — Manual failover: `{"target": "primary"|"secondary"}`
- `GET /api/failover/status` — Current failover state

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
4. Upload Snowflake RSA private key to Key Vault: `snowflake-private-key`
5. Deploy the Azure Function code from `failover-function/`

## Testing the Architecture

1. **Connect via Bastion** to the jumpbox VM (`vm-jumpbox-001`) in Azure Portal
   - Username: `sqladmin` / Password: `demo!pass123`
2. **Open a browser** on the jumpbox and navigate to the SQL Tester app:
   ```
   https://ca-sql-tester-001.graypond-c3c5a3bf.eastus2.azurecontainerapps.io
   ```
3. **Enter connection details:**
   - Host: `10.1.3.10` (App Gateway private IP)
   - Port: `1433`
   - Username: `sqladmin` / Password: `demo!pass123`
   - Query: `SELECT TOP 10 FirstName, LastName FROM AdventureWorks2022.Person.Person`
4. Click **Test Connection** — traffic flows: App Gateway → PE → PLS → ILB → SQL VM

## AdventureWorks Database

The AdventureWorks2022 sample database is configured on all 4 SQL Server VMs.

## Project Structure

```
├── .azure/                        # Infrastructure plan JSON
├── docs/                          # Architecture diagrams (Mermaid)
├── failover-function/             # Azure Function for automated failover
│   ├── function_app.py            # Main function code
│   ├── requirements.txt           # Python dependencies
│   └── host.json                  # Function host config
├── test-app/                      # SQL connectivity tester Flask app
│   ├── app.py                     # Flask web UI
│   ├── Dockerfile                 # Container image with ODBC driver
│   └── requirements.txt           # Python dependencies
├── infra/                         # Terraform IaC
│   ├── main.tf                    # Root module
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Outputs
│   ├── terraform.tfvars.example   # Example variable values
│   └── modules/
│       ├── compute/               # SQL Server VMs
│       ├── networking/            # VNets, subnets, NSGs
│       ├── loadbalancer/          # Internal Standard LBs
│       ├── privatelink/           # Private Link Services
│       ├── appgateway/            # App Gateway + Private Endpoints
│       ├── testapp/               # Container App for SQL testing
│       ├── failover/              # Function App, Alerts, Key Vault
│       ├── monitoring/            # Log Analytics
│       └── storage/               # Cloud Witness storage
└── scripts/                       # AdventureWorks setup script
```
