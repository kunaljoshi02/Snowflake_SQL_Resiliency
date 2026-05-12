# Architecture Diagram

## Full Architecture

```mermaid
flowchart TB
    subgraph SNOWFLAKE["Snowflake - Business Critical"]
        direction TB
        SF_PRIMARY["Snowflake Primary<br/>East US 2"]
        SF_SECONDARY["Snowflake Secondary<br/>West US 3"]
        SF_NR["Network Rule<br/>PRIVATE_HOST_PORT"]
        SF_PRIMARY --- SF_NR
        SF_SECONDARY --- SF_NR
    end

    subgraph AZURE_SUB["Azure Subscription - rg-snowflake-sql-resiliency"]
        direction TB

        subgraph APPGW_LAYER["Application Gateway Layer - East US 2"]
            direction TB
            APPGW["App Gateway v2<br/>agw-sql-eastus2-001<br/>Private: 10.1.3.10<br/>L4 TCP :1433"]
            PE_PRI["PE to Primary PLS<br/>10.1.4.4"]
            PE_SEC["PE to Secondary PLS<br/>10.1.4.5"]
            APPGW -->|backend pool| PE_PRI
            APPGW -->|backend pool| PE_SEC
        end

        subgraph FAILOVER_AUTO["Failover Automation"]
            MONITOR["Azure Monitor Alerts"]
            FUNC["Azure Function"]
            MONITOR -->|webhook| FUNC
        end

        subgraph REGION_PRIMARY["East US 2 - Primary"]
            VM_PRI["2x SQL VMs<br/>Zones 1+2"]
            ILB_PRI["ILB 10.1.1.10"]
            PLS_PRI["PLS eastus2"]
            VM_PRI --> ILB_PRI --> PLS_PRI
        end

        subgraph REGION_SECONDARY["West US 3 - Secondary"]
            VM_SEC["2x SQL VMs<br/>Zones 2+3"]
            ILB_SEC["ILB 10.2.1.10"]
            PLS_SEC["PLS westus3"]
            VM_SEC --> ILB_SEC --> PLS_SEC
        end

        subgraph TEST["Test App"]
            CA["Container App<br/>SQL Tester UI"]
        end

        PE_PRI -->|PE tunnel| PLS_PRI
        PE_SEC -->|PE tunnel cross-region| PLS_SEC
        CA -->|SQL via| APPGW
        REGION_PRIMARY <-->|VNet Peering + AG replication| REGION_SECONDARY
    end

    SF_NR -->|PE| PLS_PRI
    SF_NR -.->|PE standby| PLS_SEC
    FUNC -->|ALTER NETWORK RULE| SNOWFLAKE
    MONITOR --> ILB_PRI
    MONITOR --> ILB_SEC
```

## Data Flow

```
Test App / Snowflake
    |
    v
App Gateway (10.1.3.10:1433)   <-- L4 TCP proxy, health-checks both backends
    |
    +---> PE (10.1.4.4) ---> PLS East US 2 ---> ILB (10.1.1.10) ---> SQL VMs (Primary)
    |
    +---> PE (10.1.4.5) ---> PLS West US 3 ---> ILB (10.2.1.10) ---> SQL VMs (Secondary)
```

## Component Summary

| Component | Resource | Purpose |
|-----------|----------|---------|
| **App Gateway v2** | agw-sql-eastus2-001 | L4 TCP proxy with health-based routing to both SQL regions |
| **PE Primary** | pe-pls-primary-sql (10.1.4.4) | Private tunnel to East US 2 PLS |
| **PE Secondary** | pe-pls-secondary-sql (10.1.4.5) | Private tunnel to West US 3 PLS (cross-region) |
| **SQL VMs** | 4x Standard_E4ds | SQL Server 2022 with AdventureWorks2022 |
| **ILB** | 2x Standard Internal LB | AG listener port 1433, floating IP |
| **PLS** | 2x Private Link Service | Expose ILBs to PEs |
| **Test App** | Container App | Web UI for SQL connectivity testing |
| **Failover Function** | Azure Function | Automated Snowflake network rule failover |
