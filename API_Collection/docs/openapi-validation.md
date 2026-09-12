# OpenAPI Validation

The build should keep OpenAPI generation healthy by compiling controllers, DTOs, validation annotations, and Springdoc configuration.

Current local validation command:

```bash
mvn -DskipTests compile
```

Recommended CI addition:

```bash
mvn -DskipTests compile
```

For client generation, start the API and export:

```bash
curl http://localhost:8080/v3/api-docs -o openapi.json
```

Then generate a Dart client with OpenAPI Generator:

```bash
openapi-generator-cli generate -i openapi.json -g dart-dio -o generated/flutter_api_client
```
