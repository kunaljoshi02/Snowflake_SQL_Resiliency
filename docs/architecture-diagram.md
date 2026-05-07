# Architecture Diagram

## Full Architecture

```mermaid
flowchart TB
    subgraph SNOWFLAKE["☁️ Snowflake - Business Critical"]
        direction TB
        SF_PRIMARY["Snowflake Primary<br/>East US 2"]
        SF_SECONDARY["Snowflake Secondary<br/>West US 3"]
        SF_NR["Network Rule<br/>PRIVATE_HOST_PORT"]
        SF_PRIMARY --- SF_NR
        SF_SECONDARY --- SF_NR
    end

    subgraph AZURE_SUB["Azure Subscription - rg-snowflake-sql-resiliency"]
        direction TB

        subgraph FAILOVER_AUTO["Failover Automation"]
            direction LR
            MONITOR["Azure Monitor<br/>Metric Alerts<br/>DipAvailability<br/>VipAvailability"]
            ACTION_GRP["Action Group"]
            FUNC["Azure Function<br/>Python - JWT Auth<br/>State Mgmt<br/>Cooldown"]
            KV["Key Vault<br/>Snowflake Key"]
            MONITOR -->|alert fired| ACTION_GRP
            ACTION_GRP -->|webhook| FUNC
            FUNC -->|read key| KV
        end

        subgraph REGION_PRIMARY["East US 2 - Primary"]
            direction TB
            subgraph VNET_PRI["VNet 10.1.0.0/16"]
                direction TB
                subgraph SNET_SQL_PRI["snet-sql 10.1.1.0/24"]
                    VM1_PRI["vm-sql-eastus2-001<br/>SQL 2022 Zone 1<br/>AdventureWorks2022"]
                    VM2_PRI["vm-sql-eastus2-002<br/>SQL 2022 Zone 2<br/>AdventureWorks2022"]
                end
                subgraph SNET_PLS_PRI["snet-pls NAT 10.1.2.0/24"]
                    PLS_PRI["Private Link Service<br/>pls-sql-eastus2-001"]
                end
            end
            ILB_PRI["Standard ILB<br/>10.1.1.10 port 1433<br/>Floating IP - AG Listener"]
            NAT_PRI["NAT Gateway"]
            VM1_PRI & VM2_PRI -->|backend pool| ILB_PRI
            ILB_PRI -->|frontend IP| PLS_PRI
            SNET_SQL_PRI --- NAT_PRI
        end

        subgraph REGION_SECONDARY["West US 3 - Secondary"]
            direction TB
            subgraph VNET_SEC["VNet 10.2.0.0/16"]
                direction TB
                subgraph SNET_SQL_SEC["snet-sql 10.2.1.0/24"]
                    VM1_SEC["vm-sql-westus3-001<br/>SQL 2022 Zone 2<br/>AdventureWorks2022"]
                    VM2_SEC["vm-sql-westus3-002<br/>SQL 2022 Zone 3<br/>AdventureWorks2022"]
                end
                subgraph SNET_PLS_SEC["snet-pls NAT 10.2.2.0/24"]
                    PLS_SEC["Private Link Service<br/>pls-sql-westus3-001"]
                end
            end
            ILB_SEC["Standard ILB<br/>10.2.1.10 port 1433<br/>Floating IP - AG Listener"]
            NAT_SEC["NAT Gateway"]
            VM1_SEC & VM2_SEC -->|backend pool| ILB_SEC
            ILB_SEC -->|frontend IP| PLS_SEC
            SNET_SQL_SEC --- NAT_SEC
        end

        subgraph SHARED["Shared Resources"]
            PEERING["Global VNet Peering<br/>Bidirectional"]
            WITNESS["Cloud Witness<br/>Storage Account<br/>East US - 3rd region"]
            LOG["Log Analytics<br/>Workspace"]
        end

        VNET_PRI <-->|WSFC and AG replication| PEERING
        PEERING <-->|async commit| VNET_SEC
    end

    SF_NR -->|active PE path| PLS_PRI
    SF_NR -.->|standby PE path| PLS_SEC

    MONITOR -->|watch health| ILB_PRI
    MONITOR -->|watch health| ILB_SEC
    FUNC -->|ALTER NETWORK RULE via SQL API| SNOWFLAKE

    VM1_PRI & VM2_PRI & VM1_SEC & VM2_SEC -.->|quorum| WITNESS
```

## Automated Failover Sequence

```mermaid
sequenceDiagram
    participant M as Azure Monitor
    participant AG as Action Group
    participant F as Azure Function
    participant KV as Key Vault
    participant S as Snowflake SQL API
    participant T as Table Storage

    Note over M: ILB health probe<br/>drops below 50%

    M->>AG: Alert Fired - DipAvailability below threshold
    AG->>F: Webhook POST /api/failover

    F->>T: Check current state and cooldown
    T-->>F: active_region=primary and not in cooldown

    F->>F: Verify failed region is the active region

    F->>KV: Get Snowflake private key
    KV-->>F: RSA private key PEM

    F->>F: Generate JWT token with keypair auth

    F->>S: POST /api/v2/statements<br/>ALTER NETWORK RULE SET VALUE_LIST
    S-->>F: Statement executed successfully

    F->>T: Update state to active_region=secondary

    Note over S: Snowflake now routes<br/>via PE to PLS West US 3
```

## Failover Scenarios

```mermaid
graph LR
    subgraph Normal["Normal Operation"]
        A1[Snowflake East US 2] -->|PE| B1[PLS East US 2] --> C1[ILB to SQL Primary]
    end

    subgraph SQLFail["SQL Primary Failure"]
        A2[Snowflake East US 2] -->|PE| B2[PLS West US 3] --> C2[ILB to SQL Secondary]
    end

    subgraph SFFail["Snowflake Failover"]
        A3[Snowflake West US 3] -->|PE| B3[PLS East US 2] --> C3[ILB to SQL Primary]
    end

    subgraph BothFail["Both Failover"]
        A4[Snowflake West US 3] -->|PE| B4[PLS West US 3] --> C4[ILB to SQL Secondary]
    end

    style Normal fill:#e6ffe6
    style SQLFail fill:#fff3e6
    style SFFail fill:#fff3e6
    style BothFail fill:#ffe6e6
```

## Component Summary

| Component | Resource | Purpose |
|-----------|----------|---------|
| **SQL VMs** | 4x Standard_E4ds_v5/v4 | SQL Server 2022 Enterprise with AdventureWorks2022 |
| **ILB** | 2x Standard Internal LB | AG listener on port 1433, floating IP, health probe 59999 |
| **PLS** | 2x Private Link Service | Expose ILB to Snowflake via Private Endpoints |
| **VNet Peering** | Bidirectional global | WSFC/AG replication traffic between regions |
| **Cloud Witness** | Storage Account (East US) | WSFC quorum in third region |
| **NAT Gateway** | 2x per region | Outbound internet for SQL VMs |
| **Azure Function** | Python, Consumption plan | Automated failover via Snowflake SQL API |
| **Monitor Alerts** | 4x metric alerts | DipAvailability + VipAvailability per ILB |
| **Key Vault** | Standard | Stores Snowflake RSA private key for JWT auth |
| **Log Analytics** | PerGB2018 | Centralized monitoring |
