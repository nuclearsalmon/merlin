module Merlin::Error
  # an unrecoverable fault
  class Severe < Exception
    def initialize(
      message : String,
      *nargs,
      **kwargs
    )
      super(message, *nargs, **kwargs)
    end
  end

  # a syntax building fault
  class SyntaxFault < Severe
    def initialize(
        message : String,
        cause : Exception? = nil)
      new_message = (
        "An error occured when building syntax." +
        (message.nil? ? "" : " #{message}"))
      super(new_message, cause)
    end
  end

  class ASTFault < Severe
    def initialize(
        message : String,
        cause : Exception? = nil)
      new_message = (
        "An error occured when building AST." +
        (message.nil? ? "" : " #{message}"))
      super(new_message, cause)
    end
  end

  # a recoverable input error - not a fault in the parser
  class BadInput < Exception
    def initialize(
      message : String,
      *nargs,
      **kwargs
    )
      super(message, *nargs, **kwargs)
    end
  end

  # unexpected symbol when parsing
  class UnexpectedCharacter < BadInput
    def initialize(
        character : Char,
        position : Position)
      super(
        "Unexpected character:\n" +
        "'#{character}' @ #{position.to_s}")
    end
  end
end