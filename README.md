# LionAttr
Store Mongoid object in Redis for fast access. It also helps you to store object
attributes to update via Redis increamental operations.

## Motivation
One of the most popular example for this problem is tracking pageview of a web
page. Imagine if you have a blog and you want to know how many time people visit
a specific article, what would you do? An obvious way to do so is whenever a
person makes a request, you increase the record holding pageview counter by using
`mongoid#inc`. Doing this is not a good idea because it increases database
calls making your application slower.

A better solution for this problem is to keep the pageview counter in memory
(which is fast) key-value storage such as Redis. Instead of increasing the
counter by the database, we increase the counter inside Redis and save back to
the database later (like after 10 mins, 30 mins or even a day).

LionAttr provides APIs for you to do so with ease.

## Install
```
gem install lion-attr
```

## Usage
```ruby
class Article
  include Mongoid::Document
  include LionAttr
  field :url, type: String
  field :view, type: Integer

  # field :view will be stored in Redis and saved back to Mongodb later
  live :view
end

# fetch the object from Redis
article = Article.fetch('54d5f10d5675730bd1050000')
# increase its view without database hits
article.incr(:view)
#=> 10

# view is updated without object save, its updated value is available
# even when you query the object from database
article_from_another_session = Article.find('54d5f10d5675730bd1050000')
article_from_another_session.view
#=> 10
```
## Live Attribute
That counter is usually an attribute of a Model object, the difference is that
attribute will get the value from Redis instead of the database. We call it live
attribute because it tends update its value very frequently.

## Cache Object
Including LionAttr will set an after save callback to create/update the object
cache in Redis.

LionAttr stores objects as json string in Redis Hash with hash key is the full
class name of the object. Objects in the same class will be stored in the same
Hash with its identity.

Object identity is object's `id` by default but you can tell LionAttr to use
different field's value as object identity.

```ruby
class Article
  include Mongoid::Document
  include LionAttr
  field :url, type: String
  field :view, type: Integer

  # field :view will be stored in Redis and saved back to Mongodb later
  live :view
  # using :url as the key
  self.live_key = :url
end

# fetch the object using custom key
Article.fetch('http://uniqueurl.com')
```

## Increment
LionAttr focuses on improving the wellknown problem increament operator in
web application such as tracking pageviews, actions, impressions, clicks. It
provides `incr` method in both class and object scope.

```ruby
article.incr(:view)
Article.incr('54d5f10d5675730bd1050000', :view)
# also work with custom key
Article.incr('http://uniqueurl.com', :view)
```
This operator only interact with Redis. No database hits.

`incr` class method is very useful when you dont want to fetch the object from
databse nor Redis, you just want to increase the counter.

*Note*: This operator will return the increased value if the field type is
`Integer` or `Float`, otherwise a warning string will be returned.

## Save Back to Database
You might want to save back the value to the database. LionAttr also provides
`update_db` to do so.

```ruby
article.update_db
```
It's good practice if you do this periodly using the gem
[whenever](https://github.com/javan/whenever).

Simple code snippet to save back all object in Article class.

```ruby
Article.where(published: true).map! &:update_db
```

## Redis Connection Pool
LionAttr uses [Connection Pool](https://github.com/mperham/connection_pool) to
keep connections to Redis

## Configuration
LionAttr uses [Redis](https://github.com/redis/redis-rb) as Redis ruby driver.

You can pass your redis configuration to LionAttr.

```ruby
LionAttr.configure do |config|
  # Tell LionAttr to use Redis db 16
  config.redis_config = { :db => 16 }
end
```

All redis configuration used in [Redis](https://github.com/redis/redis-rb) is
valid here.

## Contributing
1. [Fork it](https://github.com/tranvictor/lion_attr/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Copyright
Copyright © 2014-2015 Victor Tran – Released under MIT License
