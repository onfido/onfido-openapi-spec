# Onfido OpenAPI specification (beta)

:warning: Our OpenAPI specification is currently in beta and we welcome any feedback. You can contact us via the issues tab or [email](mailto:openapi-feedback@onfido.com), but we don't yet officially support this specification. :warning:

This specification supports the latest version of the Onfido API.

For our latest stable release that is officially supported please use [v1.0.0](https://github.com/onfido/onfido-openapi-spec/tree/v1.0.0).

## Generating client libraries and documentation

### How to build client libraries yourself

To build python client library for instance, run:

```sh
docker run --rm -v "$PWD:/local" openapitools/openapi-generator-cli:latest \
  generate -i /local/openapi.yaml -g python -o /local/generated/artifacts/python \
  --additional-properties=packageName=onfido,useOneOfDiscriminatorLookup=true
```

The list of available generators (with options) is avaliable in [OpenAPI documentation](https://openapi-generator.tech/docs/generators/).

Please find out [here](https://openapi-generator.tech/) more information about openapi-generator-cli.

### Swagger Editor documentation and Postman collection

The following files are provided for being read with [Swagger Editor](https://editor.swagger.io/) and [Postman](https://www.postman.com/):

- [openapi.yaml](generated/artifacts/openapi-yaml/openapi/openapi.yaml) (preferred)
- [openapi.json](generated/artifacts/openapi/openapi.json)
