# Onfido OpenAPI specification

## Introduction

This specification supports the latest version of the Onfido API (v3.6).

It can also be used for generating client libraries to allow backend services to interact with the Onfido API. A [Postman collection](#api-documentation) is provided as well for user's convenience.

## Client libraries

Client libraries are built by Onfido in 5 different programming languages.

Nevertheless, users can generate libraries in any other language supported by the [OpenAPI Generator](https://openapi-generator.tech).

### How to use pre-built client libraries

The libraries below are generated and maintained by Onfido:

- [onfido-java](https://github.com/onfido/onfido-java)
- [onfido-node](https://github.com/onfido/onfido-node)
- [onfido-php](https://github.com/onfido/onfido-php)
- [onfido-python](https://github.com/onfido/onfido-python)
- [onfido-ruby](https://github.com/onfido/onfido-ruby)

Libraries come with Webhook Events validation and the possibility to easily choose a region to target.

Please find more information regarding how to use each library within their own README.md file.

### How to build client libraries yourself

Please find in [OpenAPI Generator documentation](https://openapi-generator.tech) how to build client libraries and all the supported programming languages to build client libraries.

The file [openapi.yaml](https://github.com/onfido/onfido-openapi-spec/blob/master/openapi.yaml) should be provided to the generator.

We recommend providing the generator with the options below (whenever available):

```yaml
enumUnknownDefaultCase: true
useOneOfDiscriminatorLookup: true
legacyDiscriminatorBehavior: false
disallowAdditionalPropertiesIfNotPresent: false
```

## API Documentation

The [openapi-reference/openapi.json](generated/artifacts/openapi-reference/openapi.json) file can be used to explore the OpenAPI definition with tools like [Swagger Editor](https://editor.swagger.io/?url=https://raw.githubusercontent.com/onfido/onfido-openapi-spec/master/generated/artifacts/openapi-reference/openapi.json).

A pre-compiled Postman collection is also available in the Onfido [documentation portal](https://documentation.onfido.com/#postman).

## Development

Most of the contents in client libraries are auto-generated using [OpenAPI Generator](https://openapi-generator.tech).

Generation is controlled by configuration and template files stored in [each generator's folder](https://github.com/onfido/onfido-openapi-spec/tree/master/generators).

### Exclusion lists

A few exceptions come from a global exclusion list (defined as part of the rsync command in [github workflow](https://github.com/onfido/onfido-openapi-spec/blob/master/.github/workflows/update-specs-and-client-libraries.yaml) and [sync-lib.sh script](https://github.com/onfido/onfido-openapi-spec/blob/master/shell/sync-lib.sh)):

- `/.git*`
- `/CHANGELOG*`
- `/.openapi-generator-ignore`
- `/.openapi-generator/FILES`

For each generator, additional exclusions are defined into specific [exclusions.txt files](https://github.com/search?q=repo%3Aonfido%2Fonfido-openapi-spec+path%3A**%2Fexclusions.txt&type=code) stored in each generator's folder.

Code is automatically generated into the [generated/artifacts](https://github.com/onfido/onfido-openapi-spec/tree/master/generated/artifacts) subfolders and pushed to each client library repository via automatically generated PRs. Every path matching the exclusion lists defined above is neither copied from artifact folder nor removed from the target client library repository: that’s the way for avoid pushing some contents to client libraries but also avoiding some files (tests and git files) from being removed or overridden.

A few files are automatically generated and committed in the [generated/artifacts](https://github.com/onfido/onfido-openapi-spec/tree/master/generated/artifacts) folder at PR merge time.

### Configuration files

Configuration files are named [config.yaml](https://github.com/search?q=repo%3Aonfido%2Fonfido-openapi-spec+path%3A**%2Fconfig.yaml&type=code) and allow for the provision of custom parameters to each generator. Most parameters are defined in the [OpenAPI generator documentation](https://openapi-generator.tech/docs/generators/). A global configuration ([common/config.yaml](https://github.com/onfido/onfido-openapi-spec/blob/master/generators/common/config.yaml)) is used to store common parameters and share them among the different generators. Configuration files also include some variables (e.g. ${GENERATOR_NAME}) which are replaced before being provided to the Openapi generator (see `envsubst` command in [generate.sh](https://github.com/onfido/onfido-openapi-spec/blob/master/shell/generate.sh)).

### Templates

Templates are provided to add particular features to client libraries:

- Webhook Events validation
- Region selection
- Token provisioning
- Customisation of README.md files
- Access to common/custom report sections (when needed)
- Additional libraries for testing (when needed)

In nearly all cases, with the exception of Webhook Event Validation and README.md templates, mustache comments ({{!...}} ) are used to denote modified sections in templates.

### Updating OpenAPI generator version

To update the OpenAPI generator version, bump the version in both [update-specs-and-client-libraries.yaml](https://github.com/search?q=repo%3Aonfido%2Fonfido-openapi-spec%20path%3A*%2Fupdate-specs-and-client-libraries.yaml%20openapi-generator-cli&type=code) and [generate.sh](https://github.com/search?q=repo%3Aonfido%2Fonfido-openapi-spec+path%3Ashell%2Fgenerate.sh+OPENAPI_GENERATOR_VERSION&type=code). Afterwards run the `./shell/generate.sh` script as usual, some errors like below might be raised:

```sh
 !!! Error while building generator ...!!!

 SHA256SUM for template ... changed, diff reported below. To overwrite template, run:
 ...
```

This happens when templates we're overriding have been updated. The script automatically fixes checksums for one generator at each run, but the templates need to be carefully reviewed and updated by following the procedure below:

1. Check which files have changed, by running `git diff generators/**/templates/SHA256SUM`
2. Compare each file with the one that has been freshly generated, e.g. if _libraries/okhttp-gson/ApiClient.mustache_ checksum has been denoted as modified for _java/okhttp-gson_ generator:
   ```sh
   diff generators/java/okhttp-gson/templates/libraries/okhttp-gson/ApiClient.mustache  generated/templates/java/okhttp-gson/libraries/okhttp-gson/ApiClient.mustache
   ```
3. Add all changes from the new version except the ones noted by mustache comments (i.e. `{{! }}`)
4. Commit changes to both templates and SHA256SUM files

The changes to README.md should be carefully reviewed by comparing `generated/templates/**/README.mustache` files created with different OpenAPI generator versions.

## Contributing

Repository is open to external contributions. At this end please:

1. [Fork](https://github.com/onfido/onfido-openapi-spec/fork) repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make your changes, see below sections for project setup and testing.
4. To update one (or more) client libraries, clone them in the parent folder so that all the _onfido-\*_ repositories lie at the same level. Then run the script `./shell/generate.sh` in the _onfido-openapi-spec_ folder and `./shell/sync-lib.sh` in each of the client libraries' folder, as in the examples below:

   ```sh
   ../onfido-openapi-spec/shell/sync-lib.sh java java/okhttp-gson
   ../onfido-openapi-spec/shell/sync-lib.sh php
   ```

5. To verify changes to the OpenAPI definition with external tools, run:

   ```sh
   ./shell/refresh-openapi-spec-for-documentation.py \
           generated/artifacts/openapi/openapi.json \
           generated/artifacts/openapi-documentation/openapi.json
   ```

6. Before committing your changes, run the script `./shell/run-prettier.sh`
7. Commit your changes (`git commit -am 'Add some feature'`)
8. Push to the branch (`git push origin my-new-feature`)
9. Create a new Pull Request

## Client libraries release (internal use only)

Described below is the procedure on how to deliver new client libraries:

1. Merge all the requested PRs in [onfido-openapi-spec](https://github.com/onfido/onfido-openapi-spec) and wait for each workflow completion
2. Draft a new [onfido-openapi-spec](https://github.com/onfido/onfido-openapi-spec/releases) release using as _Release title_ last released version bumped accordingly to the type of change(s) (`vMAJOR.MINOR.PATCH`):

   | Type    | Description                                            |
   | ------- | ------------------------------------------------------ |
   | _Patch_ | changes not involving the OpenAPI spec (e.g. template) |
   | _Minor_ | backward compatible changes to the OpenAPI spec        |
   | _Major_ | non-backward compatible changes to the OpenAPI spec    |

3. Use the same _Release title_ (including `v`) to create a tag
4. Review and possibly amend release notes generated by clicking on the appropriate button
5. Enable _Set as a pre-release_ and click on _Publish release_
6. Trigger client libraries update by opening [update-specs-and-client-libraries](https://github.com/onfido/onfido-openapi-spec/actions/workflows/update-specs-and-client-libraries.yaml) and clicking over the _Run workflow_ button
7. Select the type of change:

   | Type        | Description                                                                                                           |
   | ----------- | --------------------------------------------------------------------------------------------------------------------- |
   | _No change_ | no change expected to client library code                                                                             |
   | _Patch_     | bug fix not causing any change to client library interface                                                            |
   | _Minor_     | backward compatible change to client library interface (e.g. new endpoint, new optional parameters)                   |
   | _Major_     | non-backward compatible change to client library interface (e.g. remove or change endpoint, new mandatory parameters) |

8. Select the language(s) for which client library(-ies) should be refreshed
9. Press _Run workflow_, a new PR will be created for each library or overridden if already present (steps 6-9 might be repeated)
10. For one client library at the time, check if workflows are green or update tests as needed (they can't run in parallel)
11. Reference any additional change in auto-generated PR's description, merge the PR and wait for each workflow completion
12. Draft a new client library release, by first clicking on the _Releases_ button and _Draft a new release_ afterwards
13. Use the `release` field's value from `.release.json` file as _Release title_, including the `v` prefix
14. Create a tag with same value as the _Release title_ and click on the _Generate release notes_ button
15. Copy and paste release notes `What's changed` section from onfido-openapi-spec's release notes just below the _Refresh onfido-..._ line, by:
    1. Removing lines that doesn't apply to current library and reference to current language if present
    2. Indenting of two spaces each line and replacing the intial asterix (`*`) with dash (`-`)
    3. Removing `by...` (till the end of the line) for keeping `CHANGELOG.md` file clean
16. Any additional change manually performed in the library (e.g. updated tests, etc) needs to be added after the _Refresh onfido-..._ line, indented as usual (but using `-` as a list marker to make line appearing in the `CHANGELOG.md` file).
17. Click on _Publish release_ button
18. Check that workflows have been succesfully executed (by clicking on the _Action_ button)
19. Replace `Refresh onfido-...` line in Release notes with the more appropriate `Release based on...` line from `CHANGELOG.md` file
20. Repeat steps 12-19 for each client library to deliver
21. Open onfido-openapi-spec release created a few steps before, untick _Set as a pre-release_, tick _Set as the latest release_ and click on the _Update release_ button to save it
22. If client library is targetting a new API version, update the [documentation](https://developers.onfido.com/guide/api-versioning-policy#client-libraries) with new client libraries version
