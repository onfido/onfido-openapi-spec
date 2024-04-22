# Onfido

The official Ruby library for integrating with the Onfido API.

[![Gem Version](https://badge.fury.io/rb/onfido.svg)](http://badge.fury.io/rb/onfido)
[![Build Status](https://travis-ci.org/onfido/onfido-ruby.svg?branch=master)](https://travis-ci.org/onfido/onfido-ruby)

Documentation can be found at https://documentation.onfido.com

This version uses Onfido API v3.6 and is compatible with Ruby 2.4 onwards. Refer to our [API versioning guide](https://developers.onfido.com/guide/api-versioning-policy#client-libraries) for details of which client library versions use which versions of the API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'onfido', '~> 2.0.1'
```

## Getting started

Configure with your API token and region:

```ruby
onfido = Onfido::API.new(
  api_key: ENV['ONFIDO_API_KEY'],
  # Supports :eu, :us and :ca. Previously defaulted to :eu.
  region: :eu
)
```

All resources share the same interface when making API calls. Use `.create` to create a resource, `.find` to find one, and `.all` to fetch all resources.

For example, to create an applicant:

```ruby
onfido.applicant.create(
  first_name: 'Test',
  last_name: 'Applicant'
)
```

Documentation and code examples can be found at https://documentation.onfido.com

## Error Handling

There are 3 classes of errors raised by the library, all of which subclass `Onfido::OnfidoError`:

- `Onfido::RequestError` is raised whenever Onfido returns a `4xx` response
- `Onfido::ServerError` is raised whenever Onfido returns a `5xx` response
- `Onfido::ConnectionError` is raised whenever a network error occurs (e.g., a timeout)

All 3 error classes provide the `response_code`, `response_body`, `json_body`, `type` and `fields` of the error (although for `Onfido::ServerError` and `Onfido::ConnectionError` the last 3 are likely to be `nil`).

```ruby
def create_applicant
  onfido.applicant.create(params)
rescue Onfido::RequestError => e
  e.type          # => 'validation_error'
  e.fields        # => { "email": { "messages": ["invalid format"] } }
  e.response_code # => '422'
end
```

## Other configuration

Optional configuration options with their defaults:

```ruby
onfido = Onfido::API.new(
  # ...
  open_timeout: 10,
  read_timeout: 30
)
```

## Verifying webhooks

Each webhook endpoint has a secret token, generated automatically and [exposed](https://documentation.onfido.com/#register-webhook) in the API. When sending a request, Onfido includes a signature computed using the request body and this token in the `X-SHA2-Signature` header.

You should compare this provided signature to one you generate yourself with the token to verify that a webhook is a genuine request from Onfido.

```ruby
if Onfido::Webhook.valid?(request.raw_post,
                          request.headers["X-SHA2-Signature"],
                          ENV['ONFIDO_WEBHOOK_TOKEN'])
  process_webhook
else
  render status: 498, text: "498 Token expired/invalid"
end
```

Read more at https://developers.onfido.com/guide/manual-webhook-signature-verification#webhook-security

## Contributing

1. Fork it ( https://github.com/onfido/onfido-ruby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## More documentation

More documentation and code examples can be found at https://documentation.onfido.com
