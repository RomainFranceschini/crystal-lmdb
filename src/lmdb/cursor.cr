module LMDB
  # Same as doing LMDB::Cursor::Flag.flag(*values)
  macro cursor_flags(*values)
    ::LMDB::Cursor::Flag.flags({{*values}})
  end

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
  private abstract struct ACursor
    @[Flags]
    enum Flag
      NoOverwrite = LibLMDB::NOOVERWRITE
      NoDupData   = LibLMDB::NODUPDATA
      Current     = LibLMDB::CURRENT
      Reserve     = LibLMDB::RESERVE
      Append      = LibLMDB::APPEND
      AppendDup   = LibLMDB::APPENDDUP
      Multiple    = LibLMDB::MULTIPLE
    end

    @handle : LibLMDB::Cursor

    def initialize(transaction : ATransaction, database : Database)
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

    # Returns the number of duplicates for the current key.
    #
    # This call is only valid on databases configured with sorted duplicates.
    def count
      LMDB.check LibLMDB.cursor_count(self, out count)
      count
    end

    # Set `self` to point to the first record in the database and returns the
    # associated record.
    def first : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::First)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Returns the record currently pointed at.
    def get : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::GetCurrent)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Returns the record currently pointed at, or `nil`.
    def get? : {Value, Value}?
      ret = LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::GetCurrent)
      if ret == Error::Code::NotFound.value
        nil
      else
        {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
      end
    end

    # Set the cursor to the next record in the database, and return it.
    def next : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::Next)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Set the cursor to the next record in the database, and return it.
    def next? : {Value, Value}?
      ret = LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::Next)
      if ret == Error::Code::NotFound.value
        nil
      else
        {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
      end
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::Prev)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Set the cursor to the prev record in the database, and return it.
    def prev? : {Value, Value}?
      ret = LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::Prev)
      if ret == Error::Code::NotFound.value
        nil
      else
        {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
      end
    end

    # Set `self` to point to the last record in the database and returns the
    # associated record.
    def last : {Value, Value}
      LMDB.check LibLMDB.cursor_get(self, out key, out val, LibLMDB::CursorOp::Last)
      {Value.new(key.size, key.data.as(UInt8*)), Value.new(val.size, val.data.as(UInt8*))}
    end

    # Set `self` to point at the given *key*.
    def set(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, LibLMDB::CursorOp::Set)
      Value.new(val.size, val.data.as(UInt8*))
    end

    # ditto
    def set(key : K) : Value forall K
      set(pointerof(key))
    end

    # Set `self` to point at the first key greater than or equal to the given
    # *key*.
    def set_range(key : String | Pointer(K) | Slice(K) | Array(K) | StaticArray(K, _)) : Value forall K
      dbk = Value.new(key)
      LMDB.check LibLMDB.cursor_get(self, dbk, out val, LibLMDB::CursorOp::SetRange)
      Value.new(val.size, val.data.as(UInt8*))
    end

    # ditto
    def set_range(key : K) : Value forall K
      set_range(pointerof(val))
    end

    def to_unsafe
      @handle
    end
  end

  # Read/write cursor.
  struct Cursor < ACursor
    def readonly?
      false
    end

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
            value : String | Pointer(V) | Slice(V) | Array(V) | StaticArray(V, _)) forall K, V
      dbk = Value.new(key)
      dbv = Value.new(value)
      LMDB.check LibLMDB.cursor_put(self, dbk, dbv, 0)
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

    # Delete current key/value pair.
    def delete
      LMDB.check LibLMDB.cursor_del(self, 0)
    end

    # Delete all data associated with the current key.
    #
    # NOTE: This method should only be called if the underlying database was
    # opened with DupSort flag.
    def delete_all
      LMDB.check LibLMDB.cursor_del(self, LibLMDB::NODUPDATA)
    end
  end

  # Readonly cursor.
  struct ReadOnlyCursor < ACursor
    def readonly?
      true
    end
  end
end
