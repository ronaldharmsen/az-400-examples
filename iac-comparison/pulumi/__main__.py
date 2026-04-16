"""Pulumi program – Azure App Service connected to a Storage Account."""

import pulumi
from pulumi_azure_native import resources, storage, web

# ---------- Configuration ----------
config = pulumi.Config()
location = config.get("location") or "westeurope"

# ---------- Resource Group ----------
resource_group = resources.ResourceGroup(
    "rg-iac-pulumi-demo",
    resource_group_name="rg-iac-pulumi-demo",
    location=location,
)

# ---------- Storage Account ----------
storage_account = storage.StorageAccount(
    "stpulumidemo",
    account_name="stpulumidemo",
    resource_group_name=resource_group.name,
    location=resource_group.location,
    sku=storage.SkuArgs(name=storage.SkuName.STANDARD_LRS),
    kind=storage.Kind.STORAGE_V2,
    enable_https_traffic_only=True,
    minimum_tls_version=storage.MinimumTlsVersion.TLS1_2,
)

# Build the storage connection string from account name + primary key
storage_keys = pulumi.Output.all(resource_group.name, storage_account.name).apply(
    lambda args: storage.list_storage_account_keys(
        resource_group_name=args[0],
        account_name=args[1],
    )
)
primary_key = storage_keys.apply(lambda keys: keys.keys[0].value)

connection_string = pulumi.Output.all(storage_account.name, primary_key).apply(
    lambda args: (
        f"DefaultEndpointsProtocol=https;"
        f"AccountName={args[0]};"
        f"AccountKey={args[1]};"
        f"EndpointSuffix=core.windows.net"
    )
)

# ---------- App Service Plan (Linux) ----------
app_service_plan = web.AppServicePlan(
    "asp-pulumi-demo",
    name="asp-pulumi-demo",
    resource_group_name=resource_group.name,
    location=resource_group.location,
    kind="linux",
    reserved=True,
    sku=web.SkuDescriptionArgs(name="B1", tier="Basic"),
)

# ---------- Web App ----------
web_app = web.WebApp(
    "app-pulumi-demo",
    name="app-pulumi-demo",
    resource_group_name=resource_group.name,
    location=resource_group.location,
    server_farm_id=app_service_plan.id,
    https_only=True,
    site_config=web.SiteConfigArgs(
        linux_fx_version="DOTNETCORE|8.0",
        app_settings=[
            web.NameValuePairArgs(
                name="StorageConnectionString",
                value=connection_string,
            ),
        ],
    ),
)

# ---------- Outputs ----------
pulumi.export("web_app_url", web_app.default_host_name.apply(lambda h: f"https://{h}"))
