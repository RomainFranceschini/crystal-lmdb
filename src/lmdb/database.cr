module LMDB
  # Same as doing LMDB::Database::Flag.flag(*values)
  macro db_flags(*values)
    ::LMDB::Database::Flag.flags({{*values}})
  end

  # A `Database` is a key-value store, which is part of an `Environment`.
  #
  # By default, each key maps to one value. However, a `Database` can be
  # configured to allow duplicate keys, in which case one key will map to
  # multiple values.
  #
  # Keys are stored in a sorted order. The order can also be configured upon
  # initialization.
  #
  # Basic operations on a database are `#put`, `#get` and `#delete` records.
  # One can also iterate through records using a `Cursor`.
  #
  # Example:
  # ```
  # env = LMDB.new "databasedir"
  # db = env.database "databasename"
  # db.put "key1", "value1"
  # db.put "key2", "value2"
  # db.get "key1" # => "value1"
  # env.close
  # ```
  class Database
    include Disposable

    @[Flags]
    enum Flag
      ReverseKey = LibLMDB::REVERSEKEY
      DupSort    = LibLMDB::DUPSORT
      IntegerKey = LibLMDB::INTEGERKEY
      DupFixed   = LibLMDB::DUPFIXED
      IntegerDup = LibLMDB::INTEGERDUP
      ReverseDup = LibLMDB::REVERSEDUP
      Create     = LibLMDB::CREATE
    end

    getter environment : Environment
    @handle : LibLMDB::Dbi

    def initialize(@environment)
    end

    # def flags(txn : Transaction) : Flag
    #   check LibLMDB.dbi_flags(txn, self, out flags)
    #   Flag.new(flags)
    # end

    #
    def clear
    end

    #
    def close
      LibLMDB.dbi_close(self)
    end

    def ==(other : self)
      @handle == other.handle
    end

    def to_unsafe
      @handle
    end
  end
end
