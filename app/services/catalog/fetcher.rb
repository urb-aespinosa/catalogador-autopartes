module Catalog
  # The only door to the network. Every response is stored as a SourceSnapshot
  # and reused on later runs, which is what makes two runs identical.
  # Failed responses are never stored. FORCE_REFRESH=1 downloads again, once
  # per URL and process.
  module Fetcher
    class SourceError < StandardError
      attr_reader :url, :detail, :status

      def initialize(url:, detail:, status: nil)
        @url = url
        @detail = detail
        @status = status
        super("#{url}: #{detail}")
      end
    end

    REFRESHED = Set.new
    REFRESH_LOCK = Mutex.new

    module_function

    def reset_refreshed! = REFRESH_LOCK.synchronize { REFRESHED.clear }

    def get(url)
      cached = cached(url)
      return cached if cached && !claim_refresh(url)

      begin
        store(url, download(url), cached)
      rescue StandardError
        REFRESH_LOCK.synchronize { REFRESHED.delete(url) }
        raise
      end
    end

    # FORCE_REFRESH=1 downloads each URL again at most once per process, so a
    # URL repeated many times in one run is not requested again and again.
    def claim_refresh(url)
      return false unless ENV["FORCE_REFRESH"] == "1"

      REFRESH_LOCK.synchronize { REFRESHED.add?(url) ? true : false }
    end

    def get_json(url)
      JSON.parse(get(url).body)
    rescue JSON::ParserError
      raise SourceError.new(url: url, detail: "la respuesta no es JSON válido")
    end

    def cached(url) = SourceSnapshot.find_by(url: url)

    # Escapes a value for use inside a URL path segment ("/" and "+" included).
    def encode_path(value) = ERB::Util.url_encode(value.to_s)

    def download(url)
      HostThrottle.instance.wait(URI(url).host)
      response = connection.get(url)
      unless response.status == 200
        raise SourceError.new(url: url, detail: "respuesta HTTP #{response.status}", status: response.status)
      end

      response
    rescue Faraday::Error => e
      raise SourceError.new(url: url, detail: network_detail(e))
    end

    # Faraday reports an open timeout as ConnectionFailed wrapping Net::OpenTimeout.
    def network_detail(error)
      if error.is_a?(Faraday::TimeoutError) || error.wrapped_exception.is_a?(Timeout::Error)
        "timeout después de #{config.timeout} s"
      else
        "error de red: #{error.class.name.demodulize}"
      end
    end

    def store(url, response, existing)
      body = response.body.to_s.b
      attributes = {
        body: body, content_type: response.headers["content-type"],
        sha256: Digest::SHA256.hexdigest(body), fetched_at: Time.current
      }
      return existing.tap { _1.update!(attributes) } if existing

      SourceSnapshot.create!(url: url, **attributes)
    rescue ActiveRecord::RecordNotUnique
      # Another job stored it while this request was in flight: keep theirs.
      SourceSnapshot.find_by!(url: url)
    end

    def connection
      Faraday.new(
        headers: { "User-Agent" => config.user_agent },
        request: { open_timeout: config.timeout, timeout: config.timeout }
      )
    end

    def config = Rails.configuration.x.catalog
  end
end
