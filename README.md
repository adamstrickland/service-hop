## Pre reqs

You're going to need to install and run RabbitMQ

To install

```bash
brew install rabbitmq
```

To run

```bash
rabbitmq-server
```

## Running

1. Start the API
```bash
cd the-api && bundle install && bundle exec rackup -p 9293
```

1. Start the Benefits API
```bash
cd benefits-api && bundle install && bundle exec rackup
```

1. Start the Benefits Service
```bash
cd benefits-service && bundle install && bundle exec bin/benefits-service serve
```

1. Simulate a client via curl
  1. First, make sure the Benefits API can be hit via HTTP
  ```bash
  curl -X GET http://localhost:9293/api/http/benefits
  ```

  1. Now, hit the service directly via a RabbitMQ topic
  ```bash
  curl -X GET http://localhost:9293/api/bunny/benefits
  ```

1. Ponder
