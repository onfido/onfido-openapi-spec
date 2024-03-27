# Onfido OpenAPI specification (beta)

:warning: Our OpenAPI specification is currently in beta and we welcome any feedback. You can contact us via the issues tab or [support portal](https://public.support.onfido.com), but we don't yet officially support this specification. :warning:

This specification supports the latest version of the Onfido API.

For our latest stable release that is officially supported please use [v1.0.0](https://github.com/onfido/onfido-openapi-spec/tree/v1.0.0).

## Client libraries

### How to build client libraries yourself

Please find out in [OpenAPI documentation](https://openapi-generator.tech) the list of available client generators and more information about openapi-generator-cli to generate client libraries in [several programming languages](https://openapi-generator.tech/docs/generators/#client-generators).

## Documentation

### Swagger Editor documentation and Postman collection

The following files are provided for being read with [Swagger Editor](https://editor.swagger.io/) and [Postman](https://www.postman.com/):

- [openapi.yaml](generated/artifacts/openapi-yaml/openapi/openapi.yaml) (preferred)
- [openapi.json](generated/artifacts/openapi/openapi.json)

## Contributing

1. [Fork](<https://github.com/onfido/onfido-openapi-spec/fork>) repository
2. Create your feature branch (`git checkout -b my-new-feature`)
4. Make your changes, see below sections for project setup and testing.
4. To test changes in one (or more) client libraries, clone them in the parent folder so that all the _onfido-*_ repositories lie at the same level. Then run the script `./shell/generate.sh` in the _onfido-openapi-spec_ folder and `./shell/sync-lib.sh` in each of the client libraries' folder, as in the examples below:
    ```sh
    ../onfido-openapi-spec/shell/sync-lib.sh node typescript-axios
    ../onfido-openapi-spec/shell/sync-lib.sh java
    ```
5. Before you commit your changes, run the script `./shell/run-prettier.sh`
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request
