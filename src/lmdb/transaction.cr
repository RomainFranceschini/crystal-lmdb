module LMDB
  abstract struct Transaction
    @handle : LibLMDB::Txn
    getter environment : Environment
    getter! database : Database

    def self.readonly_transaction(env, db = nil, parent = nil)
      ReadTransaction.new(env, db, parent)
    end

    def self.readwrite_transaction(env, db = nil, parent = nil)
      ReadWriteTransaction.new(env, db, parent)
    end

    # Whether `self` is a readonly transaction.
    abstract def readonly? : Bool

    def to_unsafe
      @handle
    end

    # Return the transaction's ID.
    def id
      LibLMDB.txn_id(self)
    end

    # Retrieve statistics for the database associated with `self` (see `#database`).
    # If no nested database has been associated with this transaction, retrieve
    # statistics from the main database.
    def stat
      db = @database || @environment.open_db(transaction : self)
      check LibLMDB.stat(self, db, out stat)
      stat
    end

    # Retrieve raw statistics for the given database, regardless of the database
    # associated with `self`.
    def stat(db : Database) : LibLMDB::Stat
      check LibLMDB.stat(self, db, out stat)
      stat
    end

    # Commit all the operations of a transaction into the database.
    def commit
      check LibLMDB.txn_commit(self)
    end

    # Abandon all the operations of the transaction instead of saving them.
    def abort
      check LibLMDB.txn_abort(self)
    end

    def ==(other : self)
      @handle == other.handle
    end
  end

  struct ReadWriteTransaction < Transaction
    def initialize(@environment : Environment, @database : Database = nil, parent : Transaction = nil)
      check LibLMDB.txn_begin(@environment, parent, 0, out @handle)
    end

    def readonly? : Bool
      false
    end
  end

  struct ReadOnlyTransaction < Transaction
    def initialize(@environment : Environment, @database : Database = nil, parent : Transaction = nil)
      check LibLMDB.txn_begin(@environment, parent, LibLMDB::RDONLY, out @handle)
    end

    def readonly? : Bool
      true
    end

    # Reset a read-only transaction
    #
    # Abort the transaction, but keep the transaction handle. `#renew` may reuse
    # the handle.
    def reset
      LibLMDB.txn_reset(self)
    end

    # Renew a read-only transaction
    #
    # Acquires a new reader lock for a transaction handle that have been
    # released by `#reset`. Must be called before a reset transaction may be
    # used again.
    def renew
      LibLMDB.txn_renew(self)
    end
  end
end
