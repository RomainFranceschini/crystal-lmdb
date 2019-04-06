module LMDB
  # Same as doing LMDB::Environment::Flag.flag(*values)
  macro env_flags(*values)
    ::LMDB::Environment::Flag.flags({{*values}})
  end

  # Unix file access privilegies.
  @[Flags]
  enum FileMode
    OwnerRead  = 0o400,
    OwnerWrite = 0o200,
    OwnerExec  = 0o100,

    GroupRead  = 0o040,
    GroupWrite = 0o020,
    GroupExec  = 0o010,

    OtherRead  = 0o004,
    OtherWrite = 0o002,
    OtherExec  = 0o001,

    # Read/Write access for everyone
    Default = OwnerRead | OwnerWrite | GroupRead | GroupWrite | OtherRead | OtherWrite,

    OwnerAll = OwnerRead | OwnerWrite | OwnerExec,
    GroupAll = GroupRead | GroupWrite | GroupExec,
    OtherAll = OtherRead | OtherWrite | OtherExec
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
    @current_transaction : AbstractTransaction?

    # Create and opens a new `Environment` under *path* with given options.
    #
    # - *max_dbs*: sets the maximum number of named databases in the environment.
    # - *mode*: the POSIX permissions to set on created files.
    # - *map_size*: sets the size of the memory map to be allocated for this
    #   environment, in bytes. The size should be a multiple of the OS page
    #   size. The default is 10485760 bytes. The size of the memory map is also
    #   the maximum size of the database.
    def initialize(path : String, flags : Flag = Flag::NoTls,
                   mode : FileMode = FileMode.new(0o644), max_dbs : Int = 0,
                   map_size : Int = 0)
      LMDB.check LibLMDB.env_create(out @handle)

      if max_dbs > 0
        LMDB.check LibLMDB.env_set_maxdbs(self, max_dbs)
      end

      if map_size > 0
        LMDB.check LibLMDB.env_set_mapsize(self, map_size)
      end

      open(path, flags, mode)
      self
    end

    # Actually opens the environment.
    private def open(path : String, flags : Flag, mode : FileMode)
      LMDB.check LibLMDB.env_open(self, path, flags.value, mode)
    rescue e
      close
      raise e
    end

    # :nodoc:
    def current_transaction? : AbstractTransaction?
      @current_transaction
    end

    # :nodoc:
    def current_transaction : AbstractTransaction
      if txn = @current_transaction
        txn
      else
        raise "An active transaction is required"
      end
    end

    # :nodoc:
    def current_transaction=(txn : AbstractTransaction?)
      @current_transaction = txn
    end

    # Returns the maximum size of keys that can be written.
    def max_key_size
      LibLMDB.env_get_maxkeysize(self)
    end

    # Set environment flags.
    def flags=(flags : Flag)
      LMDB.check LibLMDB.env_set_flags(self, flags.value, 1)
    end

    # Clears environment flags.
    def clear_flags(flags : Flag)
      LMDB.check LibLMDB.env_set_flags(self, flags.value, 0)
    end

    # Get environment flags.
    def flags : Flag
      LMDB.check LibLMDB.env_get_flags(self, out flags)
      Flag.new(flags)
    end

    # Flush the data buffers to disk.
    def sync(force : Bool)
      check LibLMDB.env_sync(self, force)
    end

    # Returns the path to the database environment files.
    def path : String
      LMDB.check LibLMDB.env_get_path(self, out path)
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
        LMDB.check LibLMDB.env_copy2(self, path, LibLMDB::CP_COMPACT)
      else
        LMDB.check LibLMDB.env_copy(self, path)
      end
    end

    # Returns raw information about `self`.
    def info : LibLMDB::Envinfo
      LMDB.check LibLMDB.env_info(self, out info)
      info
    end

    # Returns raw statistics about `self`.
    def stat : LibLMDB::Stat
      LMDB.check LibLMDB.env_stat(self, out stat)
      stat
    end

    # Set the memory map size to use for `self`.
    #
    # The size should be a multiple of the OS page size.
    # This method may be called if no transactions are active.
    def map_size=(size)
      LMDB.check LibLMDB.env_set_mapsize(self, size)
    end

    # Close the environment and release the memory map when `self` is disposed
    # (see `#close`).
    def do_close
      LibLMDB.env_close(self)
    end

    # Opens and returns the main `Database` associated with `self`. Each
    # environment has an unnamed database. Keys are Database names in the
    # unnamed database, and may be read but not written.
    #
    # A database needs to be opened (or created) within a transaction. If a
    # pending transaction for this environment exists, it will be used for this
    # purpose. Otherwise, a new `ReadOnlyTransaction` is created.
    #
    # If a transaction is created specifically, it will be commited before
    # the `Database` is returned. Otherwise, no particular action on the
    # existing pending transaction is performed.
    def database(flags : Database::Flag = LMDB.db_flags(None)) : Database
      within_transaction do |transaction|
        Database.new(self, transaction, flags)
      end
    end

    # Opens and yields the main `Database` associated with `self`. Each
    # environment has an unnamed database. Keys are Database names in the
    # unnamed database, and may be read but not written.
    #
    # A database needs to be opened (or created) within a transaction. If a
    # pending transaction for this environment exists, it will be used for this
    # purpose. Otherwise, a new `ReadOnlyTransaction` is created.
    #
    # If a transaction is created specifically, it will be commited when the
    # block goes out of scope. Otherwise, no particular action on the
    # existing pending transaction is performed.
    def database(flags : Database::Flag = LMDB.db_flags(None))
      within_transaction do |transaction|
        yield Database.new(self, transaction, flags)
      end
    end

    # Opens and returns the a *named* `Database` associated with `self`. If
    # the database is newly created, it will not be available in other
    # transactions until the transaction that is creating the database commits.
    # If the transaction creating the database aborts, the database is not
    # created.
    #
    # A database needs to be opened (or created) within a transaction. If a
    # pending transaction for this environment exists, it will be used for this
    # purpose. Otherwise, a new `Transaction` is created.
    #
    # If a transaction is created specifically, it will be commited before
    # the `Database` is returned. Otherwise, no particular action on the
    # existing pending transaction is performed.
    def database(name : String, flags : Database::Flag = LMDB.db_flags(None)) : Database
      within_transaction do |transaction|
        Database.new(self, name, transaction, flags)
      end
    end

    # Opens and yields the a *named* `Database` associated with `self`. If
    # the database is newly created, it will not be available in other
    # transactions until the transaction that is creating the database commits.
    # If the transaction creating the database aborts, the database is not
    # created.
    #
    # A database needs to be opened (or created) within a transaction. If a
    # pending transaction for this environment exists, it will be used for this
    # purpose. Otherwise, a new `Transaction` is created.
    #
    # If a transaction is created specifically, it will be commited before
    # the `Database` is returned. Otherwise, no particular action on the
    # existing pending transaction is performed.
    def database(name : String, flags : Database::Flag = LMDB.db_flags(None))
      within_transaction do |transaction|
        yield Database.new(self, name, transaction, flags)
      end
    end

    # Create and yields a transaction for use with the environment.
    #
    # The transaction commits when the block goes out of scope. It is aborted
    # if an exception is raised or if an explicit call to `Transaction#abort` is
    # made.
    def transaction(on db : Database? = nil, readonly : Bool = false)
      txn = readonly ? ReadOnlyTransaction.new(self, db) : Transaction.new(self, db)
      yield txn
      txn.commit
    rescue ex
      txn.abort if txn
      raise ex
    end

    # Create a transaction for use with the environment.
    def transaction(on db : Database? = nil, readonly : Bool = false)
      if readonly
        ReadOnlyTransaction.new(self, db)
      else
        Transaction.new(self, db)
      end
    end

    private def within_transaction(db : Database? = nil, readonly : Bool = false)
      new_txn = false
      transaction = @current_transaction || self.transaction(db, readonly).tap {
        new_txn = true
      }

      val = yield transaction

      transaction.commit if new_txn
      val
    rescue ex
      transaction.abort if transaction && new_txn
      raise ex
    end

    # Remove the given `Database`.
    def drop(db : Database)
      within_transaction do |transaction|
        LMDB.check LibLMDB.drop(transaction, self, 1)
      end
    end

    def finalize
      close
    end

    def to_unsafe
      @handle
    end
  end
end
