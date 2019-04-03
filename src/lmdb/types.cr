module LMDB
  # Supported types
  TYPES = [Bool, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, Float32, Float64, Char]

  {% begin %}
    alias Any = Union({{*TYPES}})
  {% end %}

  struct Value
    private macro check_type!(type)
      {% if !type.union? && LMDB::TYPES.any? { |t| t.resolve.class == type.class } %}
        # Support TYPES
      {% else %}
        {{ raise "Can only create LMDB::Value with types included in LMDB::TYPES, not #{type}" }}
      {% end %}
    end

    # Initialize a `LMDB::Value` from a given *pointer*. No extra memory
    # allocated.
    def initialize(ptr : Pointer(T)) forall T
      check_type!({{T}})

      @mv_size = sizeof(T)
      @mv_data = ptr.as(UInt8*)
    end

    # Initialize a `LMDB::Value` from a given slice or array. No extra memory
    # allocated.
    def initialize(slice : Slice(T) | Array(T)) forall T
      check_type!({{T}})

      ptr = slice.to_unsafe.as(UInt8*)
      @mv_size = slice.size * sizeof(T)
      @mv_data = ptr
    end

    # Initialize a `LMDB::Value` from a given string. No extra memory
    # allocated.
    def initialize(str : String)
      @mv_data = str.to_unsafe
      @mv_size = str.bytesize
    end

    # Initialize a `LMDB::Value` from a given *value*. Copies value contents to
    # a new allocated pointer.
    def initialize(value : T) forall T
      check_type!({{T}})

      @mv_size = sizeof(T)
      ptr = Pointer(T).malloc
      ptr.value = value
      @mv_data = ptr.as(UInt8*)
    end

    # Initialize `self` from a given size and a bytes pointer.
    def initialize(@mv_size : Int32, @mv_data : UInt8*) forall T
    end

    def size
      @mv_size
    end

    def to_slice : Bytes
      Bytes.new(@mv_data, @mv_size)
    end

    def to_slice(of klass : T.class) forall T
      check_type!({{T}})
      to_slice.as(Slice(T))
    end

    def string : String
      String.new(@mv_data, bytesize: @mv_size)
    end

    def slice(of klass : T.class) : Slice(T) forall T
      check_type!({{T}})
      ptr = @mv_data.as(Pointer(T))
      Slice.new(ptr, @mv_size / sizeof(T))
    end

    def array(of klass : T.class) : Array(T) forall T
      check_type!({{T}})

      count = @mv_size / sizeof(T)
      Array(T).build(count) do |buf|
        buf.copy_from(@mv_data.as(Pointer(T)), count)
        count
      end
    end

    def value(of klass : T.class) : T forall T
      check_type!({{T}})

      raise "Type mismatch: sizeof(#{T}) != #size" if sizeof(T) != @mv_size
      @mv_data.as(Pointer(T)).value
    end

    def ==(other : self)
      size == other.size && @mv_data.as(UInt8*).to_slice(size) == other.mv_data.as(UInt8*).to_slice(size)
    end

    # Returns a new `self` with a `#clone`d `#mv_data`.
    def clone
      new @mv_size, Pointer.malloc(@mv_size) { |i| @mv_data[i] }
    end

    def to_unsafe
      pointerof(@mv_size).as(LibLMDB::Val*)
    end
  end
end
