module LMDB
  # Exception thrown on invalid LMDB operations.
  class Error < ::Exception
    enum Code
      Sucess          =      0
      KeyExist        = -30799
      NotFound        = -30798
      PageNotFound    = -30797
      Corrupted       = -30796
      Panic           = -30795
      VersionMismatch = -30794
      Invalid         = -30793
      MapFull         = -30792
      DbsFull         = -30791
      ReadersFull     = -30790
      TlsFull         = -30789
      TxnFull         = -30788
      CursorFull      = -30787
      PageFull        = -30786
      MapResized      = -30785
      Incompatible    = -30784
      BadRSlot        = -30783
      BadTxn          = -30782
      BadValSize      = -30781
      BadDbi          = -30780
    end

    # The internal code associated with the failure
    getter code : Code

    def initialize(retval)
      @code = Code.new(retval)
      super(String.new(LibLMDB.strerror(@code)))
    end
  end

  def self.check(code)
    unless code == LibLMDB::SUCCESS
      raise Error.new(code)
    end
  end
end
