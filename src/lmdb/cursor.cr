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
    # include Iterator(Pair)

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

    @handle : LibLMDB::Cursor?

    # Whether `self` is a readonly cursor.
    abstract def readonly? : Bool

    # Close this cursor.
    #
    # `self` must not be used after this call.
    def close
      LMDB.check LibLMDB.cursor_close(self)
    end

    # Returns the number of duplicates for the current key.
    def count
      LMDB.check LibLMDB.cursor_count(self, out count)
      count
    end

    # mdb_cursor_open
    # mdb_cursor_get
    # mdb_cursor_put

    def to_unsafe
      @handle
    end
  end

  struct Cursor < ACursor
    def readonly?
      false
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

  struct ReadOnlyCursor < ACursor
    def readonly?
      true
    end
  end
end
