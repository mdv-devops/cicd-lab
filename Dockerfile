FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src

COPY src/CicdLab.Api/CicdLab.Api.csproj src/CicdLab.Api/

RUN dotnet restore src/CicdLab.Api/CicdLab.Api.csproj

COPY src/CicdLab.Api/ src/CicdLab.Api/

RUN dotnet publish src/CicdLab.Api/CicdLab.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0-noble-chiseled AS final

WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_HTTP_PORTS=8080

EXPOSE 8080

USER $APP_UID

ENTRYPOINT ["dotnet", "CicdLab.Api.dll"]