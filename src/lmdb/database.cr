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
  # All operations requires an active transaction opened in `#environment`.
  # If no current transaction is found, operations will fail.
  #
  # Example:
  # ```
  # env = LMDB.new "databasedir"
  # txn = env.transaction
  # db = env.database "databasename"
  # db.put "key1", "value1"
  # db.put "key2", "value2"
  # db.get "key1" # => "value1"
  # txn.commit
  # env.close
  # ```
  class Database
    include Disposable
    include Enumerable({Value, Value})
    include Iterable({Value, Value})

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

    def initialize(@environment : Environment, transaction : AbstractTransaction,
                   flags : Flag = Flag::None)
      LMDB.check LibLMDB.dbi_open(transaction, nil, flags, out handle)
      @handle = handle
    end

    def initialize(@environment : Environment, name : String,
                   transaction : AbstractTransaction, flags : Flag = Flag::None)
      LMDB.check LibLMDB.dbi_open(transaction, name, flags, out handle)
      @handle = handle
    end

    def flags(txn : Transaction) : Flag
      check LibLMDB.dbi_flags(@environment.current_transaction, self, out flags)
      Flag.new(flags)
    end

    # Empty out the database.
    #
    # This should happen within a `Transaction`.
    def clear
      LMDB.check LibLMDB.drop(@environment.current_transaction, self, 0)
    end

    # Returns the number of records in `self`.
    def size
      stat.entries
    end

    # Returns raw statistics about `self`.
    def stat
      LMDB.check LibLMDB.stat(@environment.current_transaction, self, out stat)
      stat
    end

    # See `#get`
    def [](key) : Value
      get(key)
    end

    # See `#get?`
    def []?(key) : Value?
      get?(key)
    end

    # See `#put`
    def []=(key, value)
      put(key, value)
    end

    # Stores the given key/value pair into `self`.
    #
    # By default, a matching key replaces contents with given *value* if sorted
    # duplicates are disallowed. Otherwise, a duplicate data item is appended.
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            value : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _)) forall K, V
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.put(@environment.current_transaction, self, dbk, dbv, 0)
    end

    # ditto
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _), val : V) forall K, V
      put(key, pointerof(val))
    end

    # ditto
    def put(key : K, val : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _)) forall K, V
      put(pointerof(key), val)
    end

    # ditto
    def put(key : K, val : V) forall K, V
      put(pointerof(key), pointerof(val))
    end

    # Retrieve the value associated with the given *key* from the database.
    #
    # If the database supports duplicate keys (DUPSORT), the first value for
    # the key is returned.
    # See `#cursor` to retrieve all items from a given key.
    #
    # Raises if the key is not in the database.
    def get(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.get(@environment.current_transaction, self, dbk, out dbv)
      Value.new(dbv.size, dbv.data.as(UInt8*))
    end

    # ditto
    def get(key : K) : Value forall K
      get(pointerof(key))
    end

    # Retrieve the value associated with the given *key* from the database.
    #
    # If the database supports duplicate keys (DUPSORT), the first value for
    # the key is returned.
    # See `#cursor` to retrieve all items from a given key.
    #
    # Returns `nil` if the key is not in the database.
    def get?(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value? forall K
      dbk = Value.new(key)
      ret = LibLMDB.get(@environment.current_transaction, self, dbk, out dbv)

      if ret == Error::Code::NotFound.value
        nil
      else
        Value.new(dbv.size, dbv.data.as(UInt8*))
      end
    end

    # ditto
    def get?(key : K) : Value? forall K
      get?(pointerof(key))
    end

    # Deletes the items associated with the given *key* from `self`.
    def delete(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.del(@environment.current_transaction, self, dbk, nil)
    end

    # ditto
    def delete(key : K) forall K
      delete(pointerof(key))
    end

    # Deletes all data matching the given *value* associated with *key* from
    # `self`.
    #
    # If `self` does not support sorted duplicates (DUPSORT), *value* is
    # ignored.
    def delete(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
               value : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _)) forall K, V
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.del(@environment.current_transaction, self, dbk, dbv)
    end

    # ditto
    def delete(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
               val : V) forall K, V
      delete(key, pointerof(val))
    end

    # ditto
    def delete(key : K,
               val : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _)) forall K, V
      delete(pointerof(k), val)
    end

    # ditto
    def delete(key : K, val : V) forall K, V
      delete(pointerof(key), pointerof(val))
    end

    # Create and yields a `AbstractCursor` to iterate through `self`, closed when the
    # block goes out of scope.
    #
    # The created cursor is associated with the current transaction and `self`.
    # It cannot be used after the database is closed, nor when the transaction
    # has ended. A cursor in a `Transaction` can be closed before its
    # transaction ends, and will otherwise be closed when its transaction ends.
    # A cursor in a `ReadOnlyTransaction` must be closed explicitly, before or
    # after its transaction ends. It can be reused with `Cursor#renew` before
    # finally closing it.
    def cursor(readonly : Bool = false)
      transaction = @environment.current_transaction
      cursor = if transaction.readonly?
                 ReadOnlyCursor.new(transaction, self)
               else
                 Cursor.new(transaction, self)
               end
      yield cursor
    ensure
      cursor.close if cursor
    end

    # ditto
    def cursor(readonly : Bool = false)
      transaction = @environment.current_transaction
      if transaction.readonly?
        ReadOnlyCursor.new(transaction, self)
      else
        Cursor.new(transaction, self)
      end
    end

    def each
      self.cursor do |c|
        while pair = c.next?
          yield pair
        end
      end
    end

    def each
      RecordIterator.new(cursor)
    end

    def each_key
      each { |key, _| yield key }
    end

    def do_close
      LibLMDB.dbi_close(self)
    end

    def ==(other : self)
      @handle == other.handle
    end

    def to_unsafe
      @handle
    end

    private class RecordIterator
      include Iterator({Value, Value})

      def initialize(@cursor : AbstractCursor)
      end

      def next
        if pair = @cursor.next?
          pair
        else
          @cursor.close
          stop
        end
      end

      def rewind
        @cursor.first
      end
    end
  end
end
