module LMDB
  # Same as doing LMDB::Environment::Flag.flag(*values)
  macro env_flags(*values)
    ::LMDB::Environment::Flag.flags({{*values}})
  end

  # Class for an LMDB database environment. An environment may contain
  # multiple databases, all residing in the same shared-memory map and
  # underlying disk file. A database is a key-value table.
  #
  # An environment, and its databases, is usually stored in a directory which
  # contains two files:
  # - `data.mdb`: all records from all databases of this environment.
  # - `lock.mdb`: state of transactions that may be going on in the environment.
  #
  # To write to the environment a `Transaction` must be created. One
  # simultaneous write transaction is allowed, however there is no limit on the
  # number of read transactions even when a write transaction exists.
  #
  # Example:
  # ```
  # env = LMDB.new "mydbdir"
  # db = env.database "mydb"
  # # ...
  # env.close
  # ```
  class Environment
    include Disposable

    @[Flags]
    enum Flag
      FixedMap   = LibLMDB::FIXEDMAP
      NoSubDir   = LibLMDB::NOSUBDIR
      RdOnly     = LibLMDB::RDONLY
      WriteMap   = LibLMDB::WRITEMAP
      NoMetaSync = LibLMDB::NOMETASYNC
      NoSync     = LibLMDB::NOSYNC
      MapAsync   = LibLMDB::MAPASYNC
      NoTls      = LibLMDB::NOTLS
      NoLock     = LibLMDB::NOLOCK
      NoRdAhead  = LibLMDB::NORDAHEAD
      NoMemInit  = LibLMDB::NOMEMINIT
    end

    @handle : LibLMDB::Env

    # Yields a new `Environment`, which is automatically closed when the block
    # goes out of scope.
    #
    # Example:
    # ```
    # Environment.open("mydbdir") do |env|
    #   # ...
    # end
    # ```
    def self.open(path : String, flags : Flag = Flag::NoTls, mode = 0o0644)
      env = self.new(path, flags, mode)
      yield env
    ensure
      env.close
    end

    # Create and opens a new `Environment` under *path* with given options.
    def initialize(path : String, flags : Flag = Flag::NoTls, mode = 0o0644)
      check LibLMDB.env_create(out @handle)
      open(path, flags, mode)
    end

    # Actually opens the environment.
    #
    # Closes the environment in case
    private def open(path : String, flags : Flag, mode : Int32)
      check LibLMDB.env_open(self, path, flags.value, mode)
      self
    rescue e
      close
      raise e
    end

    # Set the maximum number of named databases for `self`.
    #
    # Set this parameter only if multiple databases will be used in the
    # environment.
    def max_named_databases=(n : Int)
      check LibLMDB.env_set_maxdbs(self, n)
    end

    # Returns the maximum size of keys that can be written.
    def max_key_size
      LibLMDB.env_get_maxkeysize(self)
    end

    # Set environment flags.
    def flags=(flags : Flag)
      check LibLMDB.env_set_flags(self, flags.value, 1)
    end

    # Clears environment flags.
    def clear_flags(flags : Flag)
      check LibLMDB.env_set_flags(self, flags.value, 0)
    end

    # Get environment flags.
    def flags : Flag
      check LibLMDB.env_get_flags(self, out flags)
      Flag.new(flags)
    end

    # Flush the data buffers to disk.
    def sync(force : Bool)
      check LibLMDB.env_sync(self, force)
    end

    # Returns the path to the database environment files.
    def path : String
      check LibLMDB.env_get_path(self, out path)
      String.new(path)
    end

    # Copy the database to another database, at the given *path*. This may be
    # used to backup an existing environment.
    #
    # If *compact* flag is set to `true`, compaction is performed while copying:
    # free pages are omitted and all pages are sequentially renumbered in output.
    # This option consumes more CPU and runs more slowly than the default.
    def dump(to path : String, compact : Bool = false)
      if compact
        check LibLMDB.env_copy2(self, path, LibLMDB::CP_COMPACT)
      else
        check LibLMDB.env_copy(self, path)
      end
    end

    # Returns raw information about `self`.
    def info : LibLMDB::Envinfo
      check LibLMDB.env_info(self, out info)
      info
    end

    # Returns raw statistics about `self`.
    def stat : LibLMDB::Stat
      check LibLMDB.env_stat(self, out stat)
      stat
    end

    # Set the memory map size to use for `self`.
    #
    # The size should be a multiple of the OS page size.
    # This method may be called if no transactions are active in this process.
    def map_size=(size)
      check LibLMDB.env_set_mapsize(self, size)
    end

    # Close the environment and release the memory map when `self` is disposed
    # (see `#close`).
    def do_close
      LibLMDB.env_close(self)
    end

    # Returns the main database associated with `self`.
    def open_db(flags : Database::Flag = Database::Flag::None,
                transaction : Transaction? = nil) : Database
      transaction = txn || begin_transaction
      check LibLMDB.dbi_open(transaction, nil, flags, out database)
      Database.new(self, database)
    ensure
      transaction.abort if txn.nil?
    end

    # Open a named database.
    def open_db(name : String, flags : Database::Flag = db_flags(None),
                transaction : Transaction? = nil) : Database
      transaction = txn || begin_transaction
      check LibLMDB.dbi_open(transaction, name, flags, out database)
      Database.new(self, database)
    ensure
      transaction.abort if txn.nil?
    end

    # Create a transaction for use with the environment.
    def begin_transaction(readonly : Bool = false)
      Transaction.new(self, readonly)
    end

    # Create and yields a transaction for use with the environment.
    #
    # The transaction commits when the block goes out of scope. It is aborted
    # if an exception is raised or if an explicit call to `Transaction#abort` is
    # made.
    def transaction(readonly : Bool = false)
      txn = begin_transaction(readonly)
      yield txn
      txn.commit
    rescue ex
      txn.abort
      raise ex
    end

    def finalize
      close
    end

    def to_unsafe
      @handle
    end
  end
end
