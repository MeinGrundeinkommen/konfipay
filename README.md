# Konfipay

Hello :) This is a gem to access the Konfipay API more easily from Ruby.

If you don't know what Konfipay is, this is probably not for you ;) Check it out here: https://portal.konfipay.de/
Note that some knowledge of concepts/workflows from EBICS and SEPA will be necessary since Konfipay does not entirely abstract those, and so neither can this gem.

This gem tries however to ease some of the underlying complexities of how financial data is handled (mostly the XML parsing/generation), and provide a nicer interface for Ruby applications (most likely Rails apps that handle SEPA debit/credit payments or need to access bank account data).

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
  # Tip: Use https://api.rubyonrails.org/classes/ActiveSupport/TaggedLogging.html
  c.logger = Rails.logger
  # You can also customize values:
  c.api_client_name = "Your organization (#{Rails.env}) #{c.api_client_name}"
end

```

### Multiple API keys

You may want to use multiple api keys, if for some use case you need to connect from the same application to different Konfipay instances, or want to use multiple keys with different permissions.

For that, you can define multiple keys like this:

```ruby

Konfipay.configure do |c|
  c.api_keys = {
    'default' => ENV.fetch('KONFIPAY_API_KEY', nil),
    'special' => ENV.fetch('KONFIPAY_OTHER_KEY', nil)
  }
end

```
The "default" key will then used by, well, default. You can select a specific key for an operation by using the "api_key_name" argument:

```ruby

# rails c
Konfipay.new_statements(
  callback_class: "KonfipayCallbacks",
  callback_method: "callback_for_new_statements",
  api_key_name: "special"
)

```

Note that you can't mix use of api_key and api_keys, define one or the other.
In a pinch, you could also override "api_key" with the operation arguments but this is discouraged, since the actual key value would then be part of the Sidekiq job payload and may leak into logs etc.


## Usage

Note: API calls handle Authentication "under the hood" by requesting a token from the API if needed, and will reauthenticate once on subsequent API calls with the same client instance. If an operation takes long, it's possible that the token
expires before the operation is finished. Retrying authentication once allows everything to finish.

### Operations

1) Fetch statements

Read account statements.

This operation comes in two "modes":
1a) "new" statements, which is fetching any recent financial statements from the account(s) configured in the Konfipay Portal. I.e. get a list of each incoming or outgoing transaction.
1b) "history" of statements, i.e. get a list of financial statements in a given timeframe.

To use this, make sure sidekiq is running, then kick off the fetching like this, for example from the Rails console:

```ruby

# rails c
Konfipay.new_statements(
  callback_class: "KonfipayCallbacks",
  callback_method: "callback_for_new_statements",
  iban: "optional iban to filter by"
)

```

or

```ruby

Konfipay.statement_history(
  callback_class: "KonfipayCallbacks",
  callback_method:"callback_for_history_statements",
  queue: :critical,
  iban: "optional iban to filter by",
  from: "2022-01-15",
  to: "2022-01-31"
)

```

You will notice that these methods immediately return just "true". This is because all operations are actually executed asynchronously as Jobs in Sidekiq (you can set the queue to be used for the job with the queue argument, it defaults to :default).
But where does the data end up, you ask?
You need to set up a simple class with a class method where you will receive asynchronous updates for each operation:


```ruby

# lib/konfipay_callbacks.rb # for example, a model works too, this class just needs to be loaded in the Sidekiq process
class KonfipayCallbacks

  def self.callback_for_new_statements(statements, transaction_id)
    pp statements
  end
end

```

KonfipayCallbacks::callback_for_new_statements will then be called in Sidekiq with the transaction data.


See each operation's method for details on parameters and callback arguments.
Please note that callbacks can be called multiple times, depending on the operation.
Also note that parameters need to be JSON-compatible - use strings as hash keys, no symbols, and no complex datatypes! Similarly, all returned data, while being Ruby objects, are also all JSON-compatible (for example, dates are formatted as ISO-8601 strings, no symbols, etc.).



2) Initializing Transfers

Send money to or receive money from one or more recipients.

This operation comes in two "modes":
2a) credit transfer - send out money
2b) direct debit - pull in money

The difference is just which method is called, and the payment data needed. The general workflow is also the same as for reading account info. Note that these operations will very likely call the callback method multiple times, depending on how fast Konfipay and your bank process the transfer(s). You can influence this also in Konfipay itself, there are settings to control how often it will check for EBICS protocol updates from your bank.

See Konfipay::Operations::InitializeTransfer#submit on the details of what the callback will receive.

Typically, the callback will be run once almost immediately, when the initial underlying API call is done. Unless there is an error at this step, it is typical that the callback is run for several times (once every x minutes, configurable via the `transfer_monitoring_interval`), for up to hours or days depending on how EBICS is configured. Typically VEU (https://wiki.windata.de/index.php?title=Verteilte_elektronische_Unterschrift_(VEU)) is needed, so this is the main "blocker" as people usually don't immediately sign.

Also, the workflow for processing credit transfers and direct debits in Konfipay is exactly the same (in fact, the same api calls are used, these two methods just generate different SEPA files), so it makes sense to use the same callback method for both of these to receive information about the processing progress.

```ruby

# rails c
Konfipay.initialize_credit_transfer(
  callback_class: "KonfipayCallbacks",
  callback_method: "callback_for_initialize_credit_transfer",
  payment_data: { ... payment data ... },
  transaction_id: "transaction id xyz123"
)

Konfipay.initialize_direct_debit(
  callback_class: "KonfipayCallbacks",
  callback_method: "callback_for_initialize_direct_debit",
  payment_data: { ... payment data ... },
  transaction_id: "transaction id xyz123"
)
```

See the method's descriptions on details about the payment data format.

Note that the payment_data is not passed into the Sidekiq jobs directly, as that might accidentally leak the data into logs etc. if there are issues - also systems like the Sidekiq dashboard do not handle large job arguments well. Instead this gem saves the data temporarily directly in Redis (using the same connection as Sidekiq). In case something goes very wrong, the keys have a TTL of 2 weeks so they data will not clog up Redis indefinitely.


For developing features or hacking on this gem, note that all business logic is implemented in the "Operation" classes, which
you can use directly without the Sidekiq jobs:

```ruby
Konfipay::Operations::FetchStatements.new.fetch("new", {"iban" => "an iban"}, {"mark_as_read" => false}) do |result|
  pp result
end
```

## Development Notes

See spec/examples for matching complete files for all operation types, which are also used in specs.
Don't forget to run rubocop and rspec ;)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MeinGrundeinkommen/konfipay.

