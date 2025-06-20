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
      filename : String? = @filename
    ) : self
      self.class.new(row, col, filename)
    end

    def to_s
      filename = @filename
      if filename.nil? || filename == ""
        if row > -1 && col > -1
          "<#{ @row }:#{ @col } from interpreted>"
        else
          "<interpreted>"
        end
      else
        if row > -1 && col > -1
          "<#{ @row }:#{ @col } in \"#{ filename }\">"
        else
          "<\"#{ filename }\">"
        end
      end
    end

    def <=>(other : Position)
      if (comp = self.row <=> other.row) != 0
        comp
      else
        self_filename = self.filename
        self_filename = "" if self_filename.nil?

        other_filename = other.filename
        other_filename = "" if other_filename.nil?

        self_filename <=> other_filename
      end
    end
  end
end
