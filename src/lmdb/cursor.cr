module LMDB
  # A `Cursor` points to records in a database, and is used to iterate through
  # the records in a `Database`.
  #
  # Cursors are created in the context of a `Transaction`, and should only be
  # used as long as that transaction is active. In other words, after a
  # `Transaction#commit` or `Transaction#abort`, the cursors created while
  # that transaction was active are no longer usable.
  #
  # To create a cursor, see `Database#cursor`.
  #
  # Example:
  # ```
  # LMDB.open "databasedir" do |env|
  #   env.database "databasename" do |db|
  #     db.cursor do |cursor|
  #       r1 = cursor.last         # => content of the last record
  #       r2 = cursor.first        # => content of the first record
  #       key, _ = cursor.next     # => content of the second record
  #       cursor.put key, "newval" # => replace the value of last record
  #     end
  #   end
  # end
  # ```
  abstract struct AbstractCursor
    @[Flags]
    enum PutFlags
      # Replace the item at the current cursor position. The key must be provided.
      Current = LibLMDB::CURRENT
      # Store the record only if it does not appear in the database.
      NoDupData = LibLMDB::NODUPDATA
      # Store the record only if the key does not already appear in the database.
      # The data parameter will be set to point to the existing item.
      NoOverwrite = LibLMDB::NOOVERWRITE
      # Reserve space for data, but don't store the given data. Returns a pointer
      # to be fill later in the transaction.
      Reserve = LibLMDB::RESERVE
      # Store the record at the end of the database. Fast if keys are in the
      # correct order.
      Append = LibLMDB::APPEND
      # As above, but for sorted duplicate data.
      AppendDup = LibLMDB::APPENDDUP
      # Sort multiple contiguous data in a single request.
      Multiple = LibLMDB::MULTIPLE
    end

    alias Op = LibLMDB::CursorOp

    @handle : LibLMDB::Cursor

    def initialize(transaction : AbstractTransaction, database : Database)
      LMDB.check LibLMDB.cursor_open(transaction, database, out handle)
      @handle = handle
    end

    # Whether `self` is a readonly cursor.
    abstract def readonly? : Bool

    # Close this cursor.
    #
    # `self` must not be used after this call.
    def close
      LibLMDB.cursor_close(self)
    end

    # Performs a get operation with the given *op* code.
    protected def get(op : Op) : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, op)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Performs a get operation with the given *op* code.
    protected def get?(op : Op) : {Value, Value}?
      ret = LibLMDB.cursor_get(self, out key, out val, op)
      if ret == Error::Code::NotFound.value
        nil
      else
        {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
      end
    end

    def to_unsafe
      @handle
    end
  end

  private module CursorGet(K, V)
    # Set `self` to point to the first record in the database and returns the
    # associated record.
    def first : {K, V}
      k, v = get(Cursor::Op::First)
      {k.as_value(K), v.as_value(V)}
    end

    # Returns the record currently pointed at.
    def get : {K, V}
      k, v = get(Cursor::Op::GetCurrent)
      {k.as_value(K), v.as_value(V)}
    end

    # Returns the record currently pointed at, or `nil`.
    def get? : {K, V}?
      get?(Cursor::Op::GetCurrent).try { |k, v|
        {k.as_value(K), v.as_value(V)}
      }
    end

    # Set the cursor to the next record in the database, and return it.
    def next : {K, V}
      k, v = get(Cursor::Op::Next)
      {k.as_value(K), v.as_value(V)}
    end

    # Set the cursor to the next record in the database, and return it.
    def next? : {K, V}?
      get?(Cursor::Op::Next).try { |k, v|
        {k.as_value(K), v.as_value(V)}
      }
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev : {K, V}
      k, v = get(Cursor::Op::Prev)
      {k.as_value(K), v.as_value(V)}
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev? : {K, V}?
      get?(Cursor::Op::Prev).try { |k, v|
        {k.as_value(K), v.as_value(V)}
      }
    end

    # Set `self` to point to the last record in the database and returns the
    # associated record.
    def last : {K, V}
      k, v = get(Cursor::Op::Last)
      {k.as_value(K), v.as_value(V)}
    end

    # Set `self` to point to the last record in the database and returns the
    # associated record.
    def last? : {K, V}?
      get?(Cursor::Op::Last).try { |k, v|
        {k.as_value(K), v.as_value(V)}
      }
    end

    # Set `self` to point at the given *key*.
    def move_to(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : V
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, LibLMDB::CursorCursor::Op::Set)
      Value.new(val.size, val.data.as(UInt8*)).as_value(V)
    end

    # ditto
    def move_to(key : K) : V
      {% if K == String %}
        move_to(key.to_slice)
      {% else %}
        move_to(pointerof(key))
      {% end %}
    end

    # Set `self` to point at the first key greater than or equal to the given
    # *key*.
    def set_range(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : V
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, LibLMDB::CursorCursor::Op::SetRange)
      Value.new(val.size, val.data.as(UInt8*)).as_value(V)
    end

    # ditto
    def set_range(key : K) : V
      {% if K == String %}
        set_range(key.to_slice)
      {% else %}
        set_range(pointerof(key))
      {% end %}
    end
  end

  private module ValueCursorGet
    # Set `self` to point to the first record in the database and returns the
    # associated record.
    def first : {Value, Value}
      get(Cursor::Op::First)
    end

    # Returns the record currently pointed at.
    def get : {Value, Value}
      get(Cursor::Op::GetCurrent)
    end

    # Returns the record currently pointed at, or `nil`.
    def get? : {Value, Value}?
      get?(Cursor::Op::GetCurrent)
    end

    # Set the cursor to the next record in the database, and return it.
    def next : {Value, Value}
      get(Cursor::Op::Next)
    end

    # Set the cursor to the next record in the database, and return it.
    def next? : {Value, Value}?
      get?(Cursor::Op::Next)
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev : {Value, Value}
      get(Cursor::Op::Prev)
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev? : {Value, Value}?
      get?(Cursor::Op::Prev)
    end

    # Set `self` to point to the last record in the database and returns the
    # associated record.
    def last : {Value, Value}
      get(Cursor::Op::Last)
    end

    # Set `self` to point to the last record in the database and returns the
    # associated record.
    def last? : {Value, Value}?
      get?(Cursor::Op::Last)
    end

    # Set `self` to point at the given *key*.
    def move_to(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, Cursor::Op::Set)
      Value.new(val.size, val.data.as(UInt8*))
    end

    # ditto
    def move_to(key : K) : Value forall K
      move_to(pointerof(key))
    end

    # Set `self` to point at the first key greater than or equal to the given
    # *key*.
    def set_range(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, Cursor::Op::SetRange)
      Value.new(val.size, val.data.as(UInt8*))
    end

    # ditto
    def set_range(key : K) : Value
      set_range(pointerof(key))
    end
  end

  private module CursorPut(K, V)
    # Stores the given key/value pair through `self` into the associated
    # `Database`.
    #
    # If the method fails for any reason, the state of the cursor remain
    # unaltered. If it succeeds, the cursor is positioned to refer to the newly
    # inserted record.
    #
    # By default, a matching key replaces contents with given *value* if sorted
    # duplicates are disallowed. Otherwise, a duplicate data item is appended.
    def put(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            value : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : Cursor::PutFlags = Cursor::PutFlags::None)
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.cursor_put(self, dbk, dbv, flags)
    end

    # ditto
    def put(key : Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _), val : V,
            flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      {% if V == String %}
        put(key, val.to_slice, flags)
      {% else %}
        put(key, pointerof(val), flags)
      {% end %}
    end

    # ditto
    def put(key : K, val : Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      {% if K == String %}
        put(key.to_slice, val, flags)
      {% else %}
        put(pointerof(key), val, flags)
      {% end %}
    end

    # ditto
    def put(key : K, val : V, flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
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

    # Delete current key/value pair.
    def delete
      LMDB.check LibLMDB.cursor_del(self, 0)
    end
  end

  private module ValueCursorPut
    # Stores the given key/value pair through `self` into the associated
    # `Database`.
    #
    # If the method fails for any reason, the state of the cursor remain
    # unaltered. If it succeeds, the cursor is positioned to refer to the newly
    # inserted record.
    #
    # By default, a matching key replaces contents with given *value* if sorted
    # duplicates are disallowed. Otherwise, a duplicate data item is appended.
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            value : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.cursor_put(self, dbk, dbv, 0)
    end

    # ditto
    def put(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _),
            val : V, flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      put(key, pointerof(val), flags)
    end

    # ditto
    def put(key : K, val : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _),
            flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      put(pointerof(key), val, flags)
    end

    # ditto
    def put(key : K, val : V, flags : Cursor::PutFlags = Cursor::PutFlags::None) forall K, V
      put(pointerof(key), pointerof(val), flags)
    end

    # Delete current key/value pair.
    def delete
      LMDB.check LibLMDB.cursor_del(self, 0)
    end
  end

  # Read/write cursor.
  struct Cursor(K, V) < AbstractCursor
    include CursorGet(K, V)
    include CursorPut(K, V)

    def readonly? : Bool
      false
    end
  end

  # Readonly cursor.
  struct ReadOnlyCursor(K, V) < AbstractCursor
    include CursorGet(K, V)

    def readonly? : Bool
      true
    end

    # Renews cursor, allowing its re-use
    def renew(transaction : AbstractTransaction)
      LMDB.check LibLMDB.cursor_renew(transaction, self)
    end
  end

  struct ValueCursor < AbstractCursor
    include ValueCursorGet
    include ValueCursorPut

    def readonly? : Bool
      false
    end
  end

  struct ReadOnlyValueCursor < AbstractCursor
    include ValueCursorGet

    def readonly? : Bool
      true
    end

    # Renews cursor, allowing its re-use
    def renew(transaction : AbstractTransaction)
      LMDB.check LibLMDB.cursor_renew(transaction, self)
    end
  end
end
