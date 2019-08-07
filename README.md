# crystal-lmdb

Crystal wrapper around the Lightning Memory-Mapped Database ([LMDB](https://symas.com/lmdb/)).

LMDB is a fast embedded transactional database with the following properties:
  - Key/value store.
  - Ordered map interface (keys are lexicographically sorted).
  - Reader/writers transactions that don't block each other.
  - ACID compliant, with nested transactions.

This wrapper tries to add as little overhead as possible, by avoiding copy and allocations whenever possible.

## Installation

### Requirements 

- Install [LMDB](https://symas.com/lmdb/) >= 0.9.23 on your system and makes sure the library can be found by the linker.

### Shard

1. Add the dependency to your `shard.yml`:
```yaml
dependencies:
  lmdb:
    github: rumenzu/crystal-lmdb
    version: 0.1.0
```
2. Run `shards install`

## Usage

```crystal
require "lmdb"

LMDB.open("./tmp/simpledb") do |env|
  env.transaction do
    env.open_db do |db|
      db.put('a', 'a'.ord)
      db.put('b', 'b'.ord)
      db.put('c', 'c'.ord)
    end
  end
end
```

See also the `examples` folder.

## Contributing

1. Fork it (<https://github.com/your-github-user/crystal-lmdb/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Romain Franceschini](https://github.com/RomainFranceschini) - creator and maintainer
