# Onfido OpenAPI Specification

Onfido's OpenAPI specification (current API version: v3).

Used to generate client libraries for the v3 API in the following languages:

* [PHP](https://github.com/onfido/api-php-client)

## Linting

This project uses [Spectral](https://stoplight.io/open-source/spectral/) for linting its OpenAPI definitions. The linting fail severity is set to `error` in the CI pipeline.

To run the linter locally use:

```
make lint
```

The above command will run spectral inside a docker container on your machine. The output it provides includes warnings, infos and hints, which can be discretionally resolved (only errors will fail CI).

## Support

We officially support these libraries, but for any libraries you generate with this specification, our Product Support team can only advise on a best-effort basis.

Please refer to https://developers.onfido.com and
https://documentation.onfido.com for more detailed documentation about the
Onfido API or [contact our Product Support team](mailto:api@onfido.com) via email for technical support.
