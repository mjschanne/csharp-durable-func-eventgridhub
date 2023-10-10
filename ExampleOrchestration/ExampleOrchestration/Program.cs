using Microsoft.Extensions.Azure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((hostContext, services) =>
    {
        services.AddAzureClients(clientBuilder =>
        {
            var connStr = hostContext.Configuration.GetValue<string>("BlobStorage");

            clientBuilder.AddBlobServiceClient(connStr);
            // add options values with containers involved
        });

        //var config = hostContext.Configuration.GetSection(nameof(ContainerStagesConfig));

        //services.Configure<ContainerStagesConfig>(config);

        //services.Configure<IOptions<ContainerStagesConfig>>();
    })
    .Build();

await host.RunAsync();

public class ContainerStagesConfig
{
    public string Container1Name { get; set; } = "";
    public string Container2Name { get; set; } = "";
}