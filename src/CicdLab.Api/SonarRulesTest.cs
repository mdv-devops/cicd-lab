namespace CicdLab.Api;

public static class SonarRulesTest
{
    public static bool HasProducts(IEnumerable<Product> products)
    {
        return products.Count() > 0;
    }
}