var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/", () => Results.Ok(new
{
    service = "cicd-lab-api",
    status = "running"
}));

app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy"
}));

app.MapGet("/api/version", () => Results.Ok(new
{
    version = "1.0.0"
}));

app.MapGet("/api/sum/{a:int}/{b:int}", (int a, int b) =>
{
    return Results.Ok(new
    {
        a,
        b,
        result = a + b
    });
});

app.MapGet("/api/hello", () => Results.Ok(new
{
    message = "Hello from CI/CD lab"
}));

app.MapGet("/api/multiply", (int a, int b) =>
{
    return Results.Ok(new
    {
        result = a * b
    });
});

app.Run();

public partial class Program { }