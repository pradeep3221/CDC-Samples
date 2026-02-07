FROM mcr.microsoft.com/dotnet/runtime:10.0-alpine AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src

COPY ["CdcConsumer.csproj", "./"]
RUN dotnet restore "CdcConsumer.csproj"

COPY . .
RUN dotnet build "CdcConsumer.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "CdcConsumer.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "CdcConsumer.dll"]
