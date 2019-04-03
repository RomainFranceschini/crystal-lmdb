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
  struct Cursor
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

    # mdb_cursor_open
    # mdb_cursor_close
    # mdb_cursor_get
    # mdb_cursor_put
    # mdb_cursor_del
  end
end
