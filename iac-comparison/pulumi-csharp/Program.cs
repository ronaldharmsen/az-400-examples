using Pulumi;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.Storage;
using Pulumi.AzureNative.Storage.Inputs;
using Pulumi.AzureNative.Web;
using Pulumi.AzureNative.Web.Inputs;

return await Deployment.RunAsync(() =>
{
    var config = new Config();
    var location = config.Get("location") ?? "westeurope";

    // ---------- Resource Group ----------
    var resourceGroup = new ResourceGroup("rg-iac-pulumi-csharp-demo", new ResourceGroupArgs
    {
        ResourceGroupName = "rg-iac-pulumi-csharp-demo",
        Location = location,
    });

    // ---------- Storage Account ----------
    var storageAccount = new StorageAccount("stpulumicsharpdemo", new StorageAccountArgs
    {
        AccountName = "stpulumicsharpdemo",
        ResourceGroupName = resourceGroup.Name,
        Location = resourceGroup.Location,
        Sku = new SkuArgs { Name = Pulumi.AzureNative.Storage.SkuName.Standard_LRS },
        Kind = Kind.StorageV2,
        EnableHttpsTrafficOnly = true,
        MinimumTlsVersion = MinimumTlsVersion.TLS1_2,
    });

    // Build the storage connection string from account name + primary key
    var storageKeys = Output.Tuple(resourceGroup.Name, storageAccount.Name)
        .Apply(t => ListStorageAccountKeys.InvokeAsync(new ListStorageAccountKeysArgs
        {
            ResourceGroupName = t.Item1,
            AccountName = t.Item2,
        }));

    var connectionString = Output.Tuple(storageAccount.Name, storageKeys)
        .Apply(t =>
            $"DefaultEndpointsProtocol=https;AccountName={t.Item1};" +
            $"AccountKey={t.Item2.Keys[0].Value};EndpointSuffix=core.windows.net");

    // ---------- App Service Plan (Linux) ----------
    var appServicePlan = new AppServicePlan("asp-pulumi-csharp-demo", new AppServicePlanArgs
    {
        Name = "asp-pulumi-csharp-demo",
        ResourceGroupName = resourceGroup.Name,
        Location = resourceGroup.Location,
        Kind = "linux",
        Reserved = true,
        Sku = new SkuDescriptionArgs { Name = "B1", Tier = "Basic" },
    });

    // ---------- Web App ----------
    var webApp = new WebApp("app-pulumi-csharp-demo", new WebAppArgs
    {
        Name = "app-pulumi-csharp-demo",
        ResourceGroupName = resourceGroup.Name,
        Location = resourceGroup.Location,
        ServerFarmId = appServicePlan.Id,
        HttpsOnly = true,
        SiteConfig = new SiteConfigArgs
        {
            LinuxFxVersion = "DOTNETCORE|8.0",
            AppSettings =
            {
                new NameValuePairArgs
                {
                    Name = "StorageConnectionString",
                    Value = connectionString,
                },
            },
        },
    });

    // ---------- Outputs ----------
    return new Dictionary<string, object?>
    {
        ["webAppUrl"] = webApp.DefaultHostName.Apply(h => $"https://{h}"),
    };
});
