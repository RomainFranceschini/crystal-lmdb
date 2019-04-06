module LMDB
  # Supported types
  TYPES = [Bool, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, Float32, Float64, Char]

  {% begin %}
    alias Any = Union({{*TYPES}})
  {% end %}

  struct Value
    macro check_type!(type)
      {% if !type.union? && LMDB::TYPES.any? { |t| t.resolve.class == type.class } %}
        # Support TYPES
      {% else %}
        {{ raise "LMDB wrapper doesn't support type #{type}" }}
      {% end %}
    end

    getter size : UInt64
    getter data : Pointer(UInt8)

    # Initialize a `LMDB::Value` from a given string. No extra memory
    # allocated.
    def initialize(str : String)
      @data = str.to_unsafe
      @size = str.bytesize.to_u64
    end

    # Initialize a `LMDB::Value` from a given *pointer*. No extra memory
    # allocated.
    def initialize(ptr : Pointer(T)) forall T
      check_type!({{T}})

      @size = sizeof(T).to_u64
      @data = ptr.as(UInt8*)
    end

    # Initialize a `LMDB::Value` from a given slice or array. No extra memory
    # allocated.
    def initialize(slice : Slice(T) | Array(T) | StaticArray(T, _)) forall T
      check_type!({{T}})

      ptr = slice.to_unsafe.as(UInt8*)
      @size = slice.size.to_u64 * sizeof(T)
      @data = ptr
    end

    # Initialize `self` from a given size and a bytes pointer.
    def initialize(@size : UInt64, @data : UInt8*)
    end

    # Initialize a `LMDB::Value` from a given *value*. Copies value contents to
    # a new allocated pointer.
    def initialize(value : T) forall T
      check_type!({{T}})

      @size = sizeof(T).to_u64
      ptr = Pointer(T).malloc
      ptr.value = value
      @data = ptr.as(UInt8*)
    end

    def to_slice : Bytes
      Bytes.new(@data, @size)
    end

    def as_str : String
      String.new(@data, bytesize: @size)
    end

    def as_slice(of klass : T.class) : Slice(T) forall T
      check_type!({{T}})
      ptr = @data.as(Pointer(T))
      Slice.new(ptr, @size / sizeof(T))
    end

    def as_array(of klass : T.class) : Array(T) forall T
      check_type!({{T}})

      count = @size / sizeof(T)
      Array(T).build(count) do |buf|
        buf.copy_from(@data.as(Pointer(T)), count)
        count
      end
    end

    def as_value(of klass : String.class)
      as_str
    end

    def as_value(of klass : Array(T).class) forall T
      as_array(T)
    end

    def as_value(of klass : Slice(T).class) forall T
      as_array(T)
    end

    def as_value(of klass : T.class) : T forall T
      check_type!({{T}})

      raise "Type mismatch: sizeof(#{T}) != #size" if sizeof(T) != @size
      @data.as(Pointer(T)).value
    end

    def as_bool : Bool
      as_value(Bool)
    end

    def as_char : Char
      as_value(Char)
    end

    def as_i : Int32
      as_value(Int32)
    end

    def as_f : Float64
      as_value(Float64)
    end

    def as_u8 : UInt8
      as_value(UInt8)
    end

    def as_u16 : UInt16
      as_value(UInt16)
    end

    def as_u32 : UInt32
      as_value(UInt32)
    end

    def as_u64 : UInt64
      as_value(UInt64)
    end

    def as_u128 : UInt128
      as_value(UInt128)
    end

    def as_i8 : Int8
      as_value(Int8)
    end

    def as_i16 : Int16
      as_value(Int16)
    end

    def as_i32 : Int32
      as_value(Int32)
    end

    def as_i64 : Int64
      as_value(Int64)
    end

    def as_i128 : Int128
      as_value(Int128)
    end

    def as_f64 : Float64
      as_value(Float64)
    end

    def as_f32
      as_value(Float32)
    end

    # Compare two `Value`s according to a particular transaction and database.
    # Assume both items are keys in the database.
    #
    # Returns `0` if the two objects are equal, a negative number if this object
    # is considered less than *other*, or a positive number otherwise.
    def cmp_key(other : self, txn : Transaction, db : Database)
      LibLMDB.cmp(txn, db, self, other)
    end

    # Compare two `Value`s according to a particular transaction and database.
    # Assume both items are data items in the database. The given database *db*
    # must be configured with the sorted duplicates option.
    #
    # Returns `0` if the two objects are equal, a negative number if this object
    # is considered less than *other*, or a positive number otherwise.
    def cmp_data(other : self, txn : Transaction, db : Database)
      LibLMDB.dcmp(txn, db, self, other)
    end

    def ==(other : self)
      size == other.size && @data.as(UInt8*).to_slice(size) == other.data.as(UInt8*).to_slice(size)
    end

    # Returns a new `self` with a `#clone`d `#data`.
    def clone
      new @size, Pointer.malloc(@size) { |i| @data[i] }
    end

    def to_unsafe
      pointerof(@size).as(LibLMDB::Val*)
    end
  end
end
