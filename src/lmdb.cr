require "db"
require "./lmdb/lib_lmdb"
require "./lmdb/types"
require "./lmdb/exception"
require "./lmdb/disposable"
require "./lmdb/environment"
require "./lmdb/database"
require "./lmdb/transaction"
require "./lmdb/cursor"

module LMDB
  VERSION = "0.1.0"

  # Returns a tuple of integers describing the LMBD library version that the
  # binding is linked against. The version of the binding itself is available
  # from the `VERSION` constant.
  def self.library_version : Tuple(Int32, Int32, Int32)
    LibLMDB.version(out major, out minor, out patch)
    {major, minor, patch}
  end

  # Open and yield an LMDB database `Environment`.
  #
  # Example:
  # ```
  # LMDB.open("mydbdir") do |env|
  #   # ...
  # end
  # ```
  def self.open(path : String, flags : Environment::Flags = env_flags(NoTls), mode = 0o0644) : Environment
    Environment.open(path, flags, mode) { |env| yield env }
  end
end
