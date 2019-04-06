module LMDB
  # An LMDB `Transaction`.
  #
  # TODO: NO_SYNC/NO_METASYNC options
  private abstract struct AbstractTransaction
    @handle : LibLMDB::Txn
    getter environment : Environment
    getter! database : Database
    @parent : LibLMDB::Txn?

    # Whether `self` is a readonly transaction.
    abstract def readonly? : Bool

    def initialize(@environment : Environment, @database : Database? = nil, parent : Transaction? = nil)
      LMDB.check LibLMDB.txn_begin(@environment, parent, 0, out handle)
      @handle = handle
      @parent = parent.to_unsafe if parent
      @environment.current_transaction = self
    end

    protected def initialize(@environment : Environment, @database : Database?, @handle : LibLMDB::Txn)
    end

    def to_unsafe
      @handle
    end

    # Return the transaction's ID.
    def id
      LibLMDB.txn_id(self)
    end

    # Retrieve raw statistics for the given database, regardless of the database
    # associated with `self`.
    def stat(db : Database) : LibLMDB::Stat
      LMDB.check LibLMDB.stat(self, db, out stat)
      stat
    end

    # Commit all the operations of a transaction into the database.
    def commit
      LMDB.check LibLMDB.txn_commit(self)
      drop
    end

    # Abandon all the operations of the transaction instead of saving them.
    def abort
      LibLMDB.txn_abort(self)
      drop
    end

    def ==(other : self)
      self.id == other.id
    end

    # Create a nested transaction.
    def transaction(readonly : Bool = self.readonly?)
      Transaction.new(@environment, database)
    end

    # :nodoc:
    private def drop
      if handle = @parent
        txn = readonly? ? ReadOnlyTransaction.new(@environment, @database, handle) : Transaction.new(@environment, @database, handle)
        @environment.current_transaction = txn
      else
        @environment.current_transaction = nil
      end
    end

    # Create and yields a nested transaction.
    #
    # The transaction commits when the block goes out of scope. It is aborted
    # if an exception is raised or if an explicit call to `Transaction#abort` is
    # made.
    def transaction(readonly : Bool = self.readonly?) : AbstractTransaction
      txn = readonly? ? ReadOnlyTransaction.new(@environment, @database, self) : Transaction.new(@environment, @database, self)
      yield txn
      txn.commit
    rescue ex
      txn.abort
      raise ex
    end

    # Create and returns a nested transaction.
    def transaction(readonly : Bool = self.readonly?) : AbstractTransaction
      if readonly?
        ReadOnlyTransaction.new(@environment, @database, self)
      else
        Transaction.new(@environment, @database, self)
      end
    end
  end

  struct Transaction < AbstractTransaction
    def readonly? : Bool
      false
    end
  end

  struct ReadOnlyTransaction < AbstractTransaction
    def initialize(@environment : Environment, @database : Database? = nil, parent : Transaction? = nil)
      LMDB.check LibLMDB.txn_begin(@environment, parent, LibLMDB::RDONLY, out handle)
      @handle = handle
      @parent = parent.to_unsafe if parent
      @environment.current_transaction = self
    end

    protected def initialize(@environment : Environment, @database : Database?, @handle : LibLMDB::Txn)
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
      LMDB.check LibLMDB.txn_renew(self)
    end
  end
end
