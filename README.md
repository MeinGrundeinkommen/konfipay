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
  iban: "iban to filter transactions by",
  callback_class: "::KonfipayCallbacks",
  callback_method: :wheresmymoney
)

```
KonfipayCallbacks::wheresmymoney will then be called in Sidekiq with the transaction data.
See each operation's method for details on parameters and callback arguments.
Please note that callbacks can be called multiple times, depending on the operation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MeinGrundeinkommen/konfipay.

