module Merlin
  struct Position
    include Comparable(Position)

    getter filename : String?
    getter row : Int32
    getter col : Int32

    @@default_mutex = Mutex.new
    @@default = Position.new

    def self.new
      @@default_mutex.synchronize(-> {
        default = @@default
        if default.nil?
          instance = Position.allocate
          instance.initialize
          default = instance
          instance
        else
          default
        end
      })
    end

    def self.default
      self.new
    end

    def initialize(
        @row : Int32 = -1,
        @col : Int32 = -1,
        @filename : String? = nil)
    end

    def initialize(@filename : String)
      @row = -1
      @col = -1
    end

    def clone(
        row : Int32 = @row,
        col : Int32 = @col,
        filename : String? = @filename) : self
      self.class.new(row, col, filename)
    end

    def to_s
      filename = @filename
      if filename.nil? || filename == ""
        "<#{ @row }:#{ @col }>"
      else
        "<#{ @row }:#{ @col } in \"#{ filename }\">"
      end
    end

    def <=>(other : Position)
      if self.row == other.row
        if self.col == other.col
          0
        elsif self.col < other.col
          -1
        else
          1
        end
      elsif self.row < other.row
        -1
      else
        1
      end
    end
  end
end
