using System.Diagnostics.CodeAnalysis;
using CicdLab.Api;
var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapProductEndpoints();
app.MapOrderEndpoints();
app.MapShippingEndpoints();
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

app.MapGet("/api/divide/{a:int}/{b:int}", (int a, int b) =>
{
    if (b == 0)
    {
        return Results.BadRequest(new
        {
            error = "Division by zero is not allowed"
        });
    }

    return Results.Ok(new
    {
        result = (double)a / b
    });
});

app.MapGet("/api/statistics/{a:int}/{b:int}", (int a, int b) =>
{
    var sum = a + b;
    var difference = a - b;
    var product = a * b;

    var maximum = a > b ? a : b;
    var minimum = a < b ? a : b;

    var average = (a + b) / 2.0;

    return Results.Ok(new
    {
        sum,
        difference,
        product,
        maximum,
        minimum,
        average
    });
});

app.MapGet("/api/hello-sonar", () => Results.Ok(new
{
    message = "Hello from SonarQube!",
    timestamp = DateTime.UtcNow
}));

app.MapGet("/api/check/{value:int}", (int value) =>
{
    if (value > 100)
    {
        return Results.Ok(new { message = "High value" });
    }

    return Results.Ok(new { message = "Low value" });
});

app.MapGet("/api/subtract/{a:int}/{b:int}", (int a, int b) =>
{
    return Results.Ok(new
    {
        result = a - b
    });
});

app.MapGet("/api/coverage-check/{value:int}", (int value) =>
{
    if (value > 100)
        return Results.Ok(new { result = "high" });

    return Results.Ok(new { result = "low" });
});

app.MapGet("/api/square/{number:int}", (int number) =>
{
    long result = (long)number * number;

    return Results.Ok(new
    {
        Number = number,
        Result = result
    });
});

app.MapGet("/api/discount", (decimal price, decimal percent) =>
{
    if (price < 0)
    {
        return Results.BadRequest(new
        {
            Error = "Price cannot be negative"
        });
    }

    if (percent < 0 || percent > 100)
    {
        return Results.BadRequest(new
        {
            Error = "Discount must be between 0 and 100"
        });
    }

    decimal discountAmount = Math.Round(
        price * percent / 100,
        2,
        MidpointRounding.AwayFromZero);

    decimal finalPrice = price - discountAmount;

    return Results.Ok(new
    {
        OriginalPrice = price,
        DiscountPercent = percent,
        DiscountAmount = discountAmount,
        FinalPrice = finalPrice
    });
});

await app.RunAsync();

public partial class Program
{
    [ExcludeFromCodeCoverage]
    private Program()
    {
    }
}