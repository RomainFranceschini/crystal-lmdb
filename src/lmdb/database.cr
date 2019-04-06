module LMDB
  # Same as doing LMDB::Database::Flag.flag(*values)
  macro db_flags(*values)
    ::LMDB::Database::Flag.flags({{*values}})
  end

  @[Flags]
  enum PutFlags
    # Store the record only if it does not appear in the database.
    NoDupData = LibLMDB::NODUPDATA,
    # Store the record only if the key does not already appear in the database.
    # The data parameter will be set to point to the existing item.
    NoOverwrite = LibLMDB::NOOVERWRITE,
    # Reserve space for data, but don't store the given data. Returns a pointer
    # to be fill later in the transaction.
    Reserve = LibLMDB::RESERVE,
    # Store the record at the end of the database. Fast if keys are in the
    # correct order.
    Append = LibLMDB::APPEND,
    # As above, but for sorted duplicate data.
    AppendDup = LibLMDB::APPENDDUP
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
      # Assume keys are string to be compared in reverse order (from end to beginning)
      ReverseKey = LibLMDB::REVERSEKEY
      # Keys are allowed to be associated with multiple data items, which are stored in a sorted fashion.
      DupSort = LibLMDB::DUPSORT
      # Keys are binary integers in native byte order and sorted as such, all key must be of the same size.
      IntegerKey = LibLMDB::INTEGERKEY
      # Multiple data items are all the same size
      DupFixed = LibLMDB::DUPFIXED
      # Duplicate data items are binary integers
      IntegerDup = LibLMDB::INTEGERDUP
      # Duplicate data items are compared in reverse order.
      ReverseDup = LibLMDB::REVERSEDUP
      # Create the database if id doesn't exist.
      Create = LibLMDB::CREATE
    end

    getter environment : Environment
    @handle : LibLMDB::Dbi

    def initialize(@environment : Environment, transaction : AbstractTransaction,
                   flags : Flag = Flag::None)
      flags = ensure_flags(flags)
      LMDB.check LibLMDB.dbi_open(transaction, nil, flags, out handle)
      @handle = handle
    end

    def initialize(@environment : Environment, name : String,
                   transaction : AbstractTransaction, flags : Flag = Flag::None)
      flags = ensure_flags(flags)
      LMDB.check LibLMDB.dbi_open(transaction, name, flags, out handle)
      @handle = handle
    end

    protected def ensure_flags(flags)
      flags
    end

    def flags : Flag
      LMDB.check LibLMDB.dbi_flags(@environment.current_transaction, self, out flags)
      Flag.new(flags.to_i)
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
    def [](key)
      get(key)
    end

    # See `#get?`
    def []?(key)
      get?(key)
    end

    # See `#put`
    def []=(key, value)
      put(key, value)
    end

    # Stores the given key/value pair into `self`.
    #
    # By default, a matching key replaces contents with given *value*.
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            value : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : PutFlags = PutFlags::None) forall K, V
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.put(@environment.current_transaction, self, dbk, dbv, 0)
    end

    # ditto
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            val : V, flags : PutFlags = PutFlags::None) forall K, V
      put(key, pointerof(val))
    end

    # ditto
    def put(key : K, val : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : PutFlags = PutFlags::None) forall K, V
      put(pointerof(key), val)
    end

    # ditto
    def put(key : K, val : V, flags : PutFlags = PutFlags::None) forall K, V
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

    private struct RecordIterator
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

  class MapDatabase(K, V) < Database
    def ensure_flags(flags)
      {% if K < Int %}
        flags | Flag::IntegerKey
      {% else %}
        flags
      {% end %}
    end

    def get(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : V
      super(key).as_value(V)
    end

    def get(key : K) : V
      {% if K == String %}
        get?(key.to_slice, val)
      {% else %}
        get?(pointerof(key), val)
      {% end %}
    end

    def get?(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : V?
      super(key).try &.as_value(V)
    end

    def get?(key : K) : Value? forall K
      {% if K == String %}
        get?(key.to_slice, val)
      {% else %}
        get?(pointerof(key), val)
      {% end %}
    end

    def delete(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _))
      dbk = Value.new(key)
      LMDB.check LibLMDB.del(@environment.current_transaction, self, dbk, nil)
    end

    def delete(key : K)
      {% if K == String %}
        delete(key.to_slice, val)
      {% else %}
        delete(pointerof(key), val)
      {% end %}
    end

    def put(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            value : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : PutFlags = PutFlags::None)
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.put(@environment.current_transaction, self, dbk, dbv, flags)
    end

    # ditto
    def put(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            val : V, flags : PutFlags = PutFlags::None)
      {% if V == String %}
        put(key, val.to_slice, flags)
      {% else %}
        put(key, pointerof(val), flags)
      {% end %}
    end

    # ditto
    def put(key : K, val : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : PutFlags = PutFlags::None)
      {% if K == String %}
        put(key.to_slice, val, flags)
      {% else %}
        put(pointerof(key), val, flags)
      {% end %}
    end

    # ditto
    def put(key : K, val : V, flags : PutFlags = PutFlags::None)
      {% if K == String && V == String %}
        put(key.to_slice, val.to_slice, flags)
      {% elsif K == String %}
        put(key.to_slice, pointerof(val), flags)
      {% elsif V == String %}
        put(pointerof(key), val.to_slice, flags)
      {% else %}
        put(pointerof(key), pointerof(val), flags)
      {% end %}
    end
  end

  class MultiDatabase < Database
    def ensure_flags(flags)
      super(flags) | Flag::DupSort
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
  end

  class MultiMapDatabase(K, V) < MapDatabase(K, V)
    def ensure_flags(flags)
      flags |= super(flags) | Flag::DupSort
      {% if V < Int %}
        flags | Flag::IntegerDup
      {% elsif LMDB::TYPES.any? { |t| t.resolve.class == V.class } %}
        flags | Flag::DupFixed
      {% else %}
        flags
      {% end %}
    end

    # Deletes all data matching the given *value* associated with *key* from
    # `self`.
    #
    # If `self` does not support sorted duplicates (DUPSORT), *value* is
    # ignored.
    def delete(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
               value : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _))
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.del(@environment.current_transaction, self, dbk, dbv)
    end

    # ditto
    def delete(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
               val : V)
      {% if V == String %}
        delete(key, val.to_slice)
      {% else %}
        delete(key, pointerof(val))
      {% end %}
    end

    # ditto
    def delete(key : K,
               val : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _))
      {% if K == String %}
        delete(key.to_slice, val)
      {% else %}
        delete(pointerof(key), val)
      {% end %}
    end

    # ditto
    def delete(key : K, val : V)
      {% if K == String && V == String %}
        delete(key.to_slice, val.to_slice)
      {% elsif K == String %}
        delete(key.to_slice, pointerof(val))
      {% elsif V == String %}
        delete(pointerof(key), val.to_slice)
      {% else %}
        delete(pointerof(key), pointerof(val))
      {% end %}
    end
  end
end
