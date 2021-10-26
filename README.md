# Konfipay

Hello :) This is a gem to access the Konfipay API more easily from Ruby.

If you don't know what Konfipay is, this is probably not for you ;) Check it out here: https://portal.konfipay.de/

This gem tries to abstract away some of the underlying complexities of how financial data is handled, and provide a nicer interface for Ruby applications (most likely Rails apps that handle SEPA debit/credit payments or need to access bank account data).

You will need a user account with Konfipay.

You also need Sidekiq configured and running in your main app - all operations are executed asynchronously, in background jobs that this gem provides.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'konfipay', git: 'https://github.com/MeinGrundeinkommen/konfipay', branch: 'main'
```

And then execute:

    $ bundle install

Development setup: Clone this gem (assumed to be on the same directory level as your main app, then set it as a local override):

    $ bundle config local.konfipay ../konfipay

Set this if branches give you trouble:

    $ bundle config disable_local_branch_check true

## Configuration

At minimum, you will need to set an api key (configure those in the Konfipay online interface).
In Rails, you'll want to use an initializer like this:

```ruby

Konfipay.configure do |c|
  c.api_key = ENV['KONFIPAY_API_KEY']
  c.logger = Rails.logger
  # You can also customize values:
  c.api_client_name = "Your organization (#{Rails.env}) #{c.api_client_name}"
end

```

## Usage

In your including Application, you need to set up a simple class with class methods where you will receive asynchronous updates for each operation:

```ruby

class KonfipayCallbacks

  def self.wheresmymoney(statements)
    pp statements
  end
end

```

Make sure sidekiq is running, then kick off an operation like this, for example from the Rails console:
```ruby

Konfipay.new_statements(
  "KonfipayCallbacks", "wheresmymoney", "optional iban to filter by"
)

```
KonfipayCallbacks::wheresmymoney will then be called in Sidekiq with the transaction data.
See each operation's method for details on parameters and callback arguments.
Please note that callbacks can be called multiple times, depending on the operation.
Also note that parameters need to be JSON-compatible - use strings as hash keys, no symbols, and no complex datatypes! Similarly, all returned data, while being Ruby objects, are also all JSON-compatible (for example, dates are formatted as ISO-8601 strings, no symbols, etc.).

For developing features or hacking on this gem, note that all business logic is implemented in the "Operation" classes, which
you can use directly without the Sidekiq jobs:

```ruby
result = Konfipay::Operations::FetchStatements.new.fetch("new", "iban": "DE36733900000000121738", 'mark_as_read': false)
```

## Development Notes

See spec/examples for matching complete files for all operation types, which are also used in specs.
Don't forget to run rubocop and rspec ;)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MeinGrundeinkommen/konfipay.

