module Sources
  # Raised when a source answered but its content can no longer be read
  # (the site changed). Reported as "error de fuente", never as "no encontrado".
  class ParseError < StandardError
    attr_reader :url, :detail

    def initialize(url:, detail:)
      @url = url
      @detail = detail
      super("#{url}: #{detail}")
    end
  end
end
