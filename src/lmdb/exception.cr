module LMDB
  # Exception thrown on invalid LMDB operations.
  class Error < ::Exception
    # The internal code associated with the failure
    getter code : Int32

    def initialize(@code)
      super(String.new(LibLMDB.strerror(@code)))
    end
  end

  def self.check(code)
    unless code == 0
      raise Error.new(code)
    end
  end
end
