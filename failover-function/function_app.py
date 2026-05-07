import os
import json
import time
import logging
import jwt
import datetime
import hashlib
import base64
import requests
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.data.tables import TableServiceClient
from cryptography.hazmat.primitives import serialization

app = func.FunctionApp()

# ─────────────────────────────────────────────────────────────────────────────
# Configuration (from environment variables)
# ─────────────────────────────────────────────────────────────────────────────
SNOWFLAKE_ACCOUNT = os.environ.get("SNOWFLAKE_ACCOUNT")  # e.g., "xy12345.east-us-2.azure"
SNOWFLAKE_USER = os.environ.get("SNOWFLAKE_USER")        # automation service account
KEY_VAULT_URL = os.environ.get("KEY_VAULT_URL")
STATE_TABLE_CONN = os.environ.get("AzureWebJobsStorage")

# Primary and secondary PLS FQDNs that Snowflake connects to
PRIMARY_PLS_HOST = os.environ.get("PRIMARY_PLS_HOST")    # e.g., "sql-primary.internal:1433"
SECONDARY_PLS_HOST = os.environ.get("SECONDARY_PLS_HOST")  # e.g., "sql-secondary.internal:1433"

# Snowflake objects to update
NETWORK_RULE_NAME = os.environ.get("SNOWFLAKE_NETWORK_RULE")  # e.g., "mydb.rules.sql_private_rule"
EXTERNAL_ACCESS_INTEGRATION = os.environ.get("SNOWFLAKE_EAI")  # e.g., "sql_access_integration"

COOLDOWN_SECONDS = int(os.environ.get("COOLDOWN_SECONDS", "300"))  # 5 min cooldown


# ─────────────────────────────────────────────────────────────────────────────
# Snowflake JWT Auth (keypair)
# ─────────────────────────────────────────────────────────────────────────────
def get_snowflake_private_key():
    """Retrieve Snowflake RSA private key from Key Vault."""
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    secret = client.get_secret("snowflake-private-key")
    return secret.value


def generate_jwt_token(account: str, user: str, private_key_pem: str) -> str:
    """Generate a Snowflake JWT token using keypair authentication."""
    qualified_username = f"{account.upper()}.{user.upper()}"

    private_key = serialization.load_pem_private_key(
        private_key_pem.encode(), password=None
    )
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    sha256_hash = hashlib.sha256(public_key_der).digest()
    public_key_fp = "SHA256:" + base64.b64encode(sha256_hash).decode("utf-8")

    now = datetime.datetime.utcnow()
    payload = {
        "iss": f"{qualified_username}.{public_key_fp}",
        "sub": qualified_username,
        "iat": now,
        "exp": now + datetime.timedelta(minutes=59),
    }
    return jwt.encode(payload, private_key, algorithm="RS256")


# ─────────────────────────────────────────────────────────────────────────────
# Snowflake SQL API
# ─────────────────────────────────────────────────────────────────────────────
def execute_snowflake_sql(token: str, statement: str) -> dict:
    """Execute a SQL statement via Snowflake SQL REST API."""
    url = f"https://{SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/statements"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT",
    }
    body = {
        "statement": statement,
        "timeout": 60,
        "role": os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
    }
    resp = requests.post(url, headers=headers, json=body, timeout=30)
    resp.raise_for_status()
    return resp.json()


# ─────────────────────────────────────────────────────────────────────────────
# State Management (Azure Table Storage)
# ─────────────────────────────────────────────────────────────────────────────
def get_state_table():
    """Get or create the failover state table."""
    service = TableServiceClient.from_connection_string(STATE_TABLE_CONN)
    service.create_table_if_not_exists("failoverstate")
    return service.get_table_client("failoverstate")


def get_current_state() -> dict:
    """Read current failover state."""
    table = get_state_table()
    try:
        entity = table.get_entity(partition_key="failover", row_key="current")
        return entity
    except Exception:
        # Initialize state
        entity = {
            "PartitionKey": "failover",
            "RowKey": "current",
            "active_region": "primary",
            "last_failover_time": "1970-01-01T00:00:00Z",
            "last_failover_reason": "initial",
            "failover_count": 0,
        }
        table.upsert_entity(entity)
        return entity


def update_state(target_region: str, reason: str):
    """Update failover state after a switch."""
    table = get_state_table()
    state = get_current_state()
    state["active_region"] = target_region
    state["last_failover_time"] = datetime.datetime.utcnow().isoformat() + "Z"
    state["last_failover_reason"] = reason
    state["failover_count"] = state.get("failover_count", 0) + 1
    table.upsert_entity(state)


def is_in_cooldown() -> bool:
    """Check if we're within the cooldown window."""
    state = get_current_state()
    last_time = state.get("last_failover_time", "1970-01-01T00:00:00Z")
    last_dt = datetime.datetime.fromisoformat(last_time.rstrip("Z"))
    elapsed = (datetime.datetime.utcnow() - last_dt).total_seconds()
    return elapsed < COOLDOWN_SECONDS


# ─────────────────────────────────────────────────────────────────────────────
# Failover Logic
# ─────────────────────────────────────────────────────────────────────────────
def perform_failover(target_region: str, reason: str) -> dict:
    """
    Switch Snowflake's network rule to point to the target region's PLS.
    
    This updates the network rule VALUE_LIST to the target PLS host,
    which redirects Snowflake's outbound PE traffic to the healthy region.
    """
    target_host = PRIMARY_PLS_HOST if target_region == "primary" else SECONDARY_PLS_HOST
    
    logging.info(f"Performing failover to {target_region} ({target_host}). Reason: {reason}")

    private_key_pem = get_snowflake_private_key()
    token = generate_jwt_token(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, private_key_pem)

    # Step 1: Update the network rule to point to the target PLS host
    alter_rule = (
        f"ALTER NETWORK RULE {NETWORK_RULE_NAME} "
        f"SET VALUE_LIST = ('{target_host}')"
    )
    result1 = execute_snowflake_sql(token, alter_rule)
    logging.info(f"Network rule updated: {result1.get('statementHandle')}")

    # Step 2: Update state
    update_state(target_region, reason)

    return {
        "action": "failover",
        "target_region": target_region,
        "target_host": target_host,
        "reason": reason,
        "snowflake_statement": result1.get("statementHandle"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Azure Function: Alert Handler
# ─────────────────────────────────────────────────────────────────────────────
@app.function_name("FailoverHandler")
@app.route(route="failover", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def failover_handler(req: func.HttpRequest) -> func.HttpResponse:
    """
    Triggered by Azure Monitor Action Group webhook.
    
    Evaluates the alert, checks state/cooldown, and performs failover if needed.
    """
    logging.info("Failover handler triggered")

    try:
        alert_data = req.get_json()
    except ValueError:
        return func.HttpResponse("Invalid JSON", status_code=400)

    # Parse Azure Monitor common alert schema
    alert_status = alert_data.get("data", {}).get("essentials", {}).get("monitorCondition", "")
    alert_name = alert_data.get("data", {}).get("essentials", {}).get("alertRule", "unknown")
    severity = alert_data.get("data", {}).get("essentials", {}).get("severity", "unknown")

    logging.info(f"Alert: {alert_name}, Status: {alert_status}, Severity: {severity}")

    # Only act on "Fired" alerts, ignore "Resolved"
    if alert_status != "Fired":
        logging.info(f"Ignoring alert with status: {alert_status}")
        return func.HttpResponse(json.dumps({
            "action": "ignored",
            "reason": f"Alert status is {alert_status}, not Fired",
        }), mimetype="application/json")

    # Check cooldown
    if is_in_cooldown():
        logging.warning("In cooldown period, skipping failover")
        return func.HttpResponse(json.dumps({
            "action": "skipped",
            "reason": "In cooldown period",
        }), mimetype="application/json")

    # Determine which region is unhealthy based on alert name
    state = get_current_state()
    current_active = state.get("active_region", "primary")

    if "primary" in alert_name.lower() or "eastus2" in alert_name.lower():
        failed_region = "primary"
        target_region = "secondary"
    elif "secondary" in alert_name.lower() or "westus3" in alert_name.lower():
        failed_region = "secondary"
        target_region = "primary"
    else:
        logging.warning(f"Cannot determine failed region from alert: {alert_name}")
        return func.HttpResponse(json.dumps({
            "action": "skipped",
            "reason": f"Cannot determine region from alert: {alert_name}",
        }), mimetype="application/json")

    # Only failover if the failed region is the currently active one
    if current_active != failed_region:
        logging.info(f"Failed region ({failed_region}) is not the active region ({current_active}). No action needed.")
        return func.HttpResponse(json.dumps({
            "action": "skipped",
            "reason": f"Failed region {failed_region} is not active ({current_active})",
        }), mimetype="application/json")

    # Perform failover
    try:
        result = perform_failover(target_region, f"Alert: {alert_name}")
        logging.info(f"Failover completed: {result}")
        return func.HttpResponse(json.dumps(result), mimetype="application/json")
    except Exception as e:
        logging.error(f"Failover failed: {str(e)}")
        return func.HttpResponse(json.dumps({
            "action": "error",
            "reason": str(e),
        }), status_code=500, mimetype="application/json")


# ─────────────────────────────────────────────────────────────────────────────
# Azure Function: Manual Failover / Status
# ─────────────────────────────────────────────────────────────────────────────
@app.function_name("FailoverStatus")
@app.route(route="failover/status", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def failover_status(req: func.HttpRequest) -> func.HttpResponse:
    """Return current failover state."""
    state = get_current_state()
    return func.HttpResponse(json.dumps({
        "active_region": state.get("active_region"),
        "last_failover_time": state.get("last_failover_time"),
        "last_failover_reason": state.get("last_failover_reason"),
        "failover_count": state.get("failover_count"),
        "in_cooldown": is_in_cooldown(),
    }), mimetype="application/json")


@app.function_name("ManualFailover")
@app.route(route="failover/switch", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def manual_failover(req: func.HttpRequest) -> func.HttpResponse:
    """
    Manual failover endpoint. POST with {"target": "primary"|"secondary"}.
    Bypasses cooldown for operator-initiated switches.
    """
    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse("Invalid JSON", status_code=400)

    target = body.get("target")
    if target not in ("primary", "secondary"):
        return func.HttpResponse(
            json.dumps({"error": "target must be 'primary' or 'secondary'"}),
            status_code=400, mimetype="application/json"
        )

    state = get_current_state()
    if state.get("active_region") == target:
        return func.HttpResponse(json.dumps({
            "action": "skipped",
            "reason": f"Already active on {target}",
        }), mimetype="application/json")

    try:
        result = perform_failover(target, "Manual operator switch")
        return func.HttpResponse(json.dumps(result), mimetype="application/json")
    except Exception as e:
        return func.HttpResponse(json.dumps({
            "action": "error",
            "reason": str(e),
        }), status_code=500, mimetype="application/json")
