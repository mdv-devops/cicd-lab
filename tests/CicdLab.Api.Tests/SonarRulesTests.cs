using Xunit;

namespace CicdLab.Api.Tests;

public class SonarRulesTests
{
    [Fact]
    public void HasProducts_WithEmptyCollection_ReturnsFalse()
    {
        var products = Array.Empty<Product>();

        var result = SonarRulesTest.HasProducts(products);

        Assert.False(result);
    }

    [Fact]
    public void HasProducts_WithProducts_ReturnsTrue()
    {
        var products = new[]
        {
            new Product(1, "Laptop", 1500),
            new Product(2, "Mouse", 50)
        };

        var result = SonarRulesTest.HasProducts(products);

        Assert.True(result);
    }
}