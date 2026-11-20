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
    public static IEnumerable<object[]> LowSeverityCases()
    {
        yield return new object[] { "Expensive", true };
        yield return new object[] { "Cheap", true };
        yield return new object[] { "Free", true };
        yield return new object[] { "Named", true };
        yield return new object[] { "LongNames", true };
        yield return new object[] { "ShortNames", true };
        yield return new object[] { "StartsWithA", true };
        yield return new object[] { "EndsWithX", true };
        yield return new object[] { "EvenIds", true };
        yield return new object[] { "OddIds", true };
    }

    [Theory]
    [MemberData(nameof(LowSeverityCases))]
    public void LowSeverityMethods_ReturnExpectedResult(
        string scenario,
        bool expected)
    {
        var products = new[]
        {
        new Product(1, "AppleLaptopX", 1500),
        new Product(2, "Mouse", 50),
        new Product(3, "Free", 0)
    };

        var result = scenario switch
        {
            "Expensive" => SonarRulesTest.HasExpensiveProducts(products),
            "Cheap" => SonarRulesTest.HasCheapProducts(products),
            "Free" => SonarRulesTest.HasFreeProducts(products),
            "Named" => SonarRulesTest.HasNamedProducts(products),
            "LongNames" => SonarRulesTest.HasProductsWithLongNames(products),
            "ShortNames" => SonarRulesTest.HasProductsWithShortNames(products),
            "StartsWithA" => SonarRulesTest.HasProductsStartingWithA(products),
            "EndsWithX" => SonarRulesTest.HasProductsEndingWithX(products),
            "EvenIds" => SonarRulesTest.HasProductsWithEvenIds(products),
            "OddIds" => SonarRulesTest.HasProductsWithOddIds(products),
            _ => throw new ArgumentOutOfRangeException(nameof(scenario))
        };

        Assert.Equal(expected, result);
    }
}