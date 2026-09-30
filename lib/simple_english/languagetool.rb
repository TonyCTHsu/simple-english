# frozen_string_literal: true

# The pinned LanguageTool distro: its version, its rules file, and the
# downloader. Everything that resolves "where it is on this machine and
# which java runs it" lives in Install. The engine runs as the daemon's
# inner HTTP server (lib/simple_english/server.rb).

module SimpleEnglish
  module LanguageTool
    RULES_FILE = File.expand_path("../../rules/simple-english.xml", __dir__)
    # The only place a LanguageTool version number appears. `se
    # setup` downloads this version, and every jar path derives from it. No
    # env var can point at another one.
    LT_VERSION = "6.6"
    CACHE_DIR_ENV = "SE_CACHE_DIR"
    JAVA_ENV = "SE_JAVA"
    # macOS ships a /usr/bin/java stub that reports no runtime. Homebrew
    # installs the real one here, outside PATH.
    HOMEBREW_JAVA = "/opt/homebrew/opt/openjdk/bin/java"
    TIMEOUT_SECONDS = 300

    module_function

    # Download and unpack the pinned LanguageTool into DIR. Idempotent:
    # returns the install directory, or nil after warning why. Pure Ruby
    # throughout: the download uses Net::HTTP and the unpack uses rubyzip,
    # so setup needs no curl or unzip on the machine.
    def install(dir)
      require "fileutils"
      dest = File.join(dir, "LanguageTool-#{LT_VERSION}")
      if File.exist?(File.join(dest, "languagetool-commandline.jar"))
        remove_stale_versions(dir, dest)
        return dest
      end
      zip = File.join(dir, "LanguageTool-#{LT_VERSION}.zip")
      FileUtils.mkdir_p(dir)
      return nil unless download(download_url, zip)
      return nil unless extract(zip, dir)
      File.delete(zip)
      remove_stale_versions(dir, dest)
      dest
    end

    def download_url
      "https://languagetool.org/download/LanguageTool-#{LT_VERSION}.zip"
    end

    # Streams URL to TO and follows redirects. Warns and returns false
    # on any transport or HTTP failure, so callers never see a stack
    # trace.
    def download(url, to, redirects: 3)
      require "net/http"
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 60) do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          case response
          when Net::HTTPRedirection
            return false if redirects.zero?
            return download(response["location"], to, redirects: redirects - 1)
          when Net::HTTPSuccess
            File.binwrite(to, "")
            File.open(to, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
            return true
          else
            warn "error: download failed: HTTP #{response.code} from #{url}"
            return false
          end
        end
      end
    rescue SystemCallError, SocketError, Timeout::Error,
      OpenSSL::SSL::SSLError, Net::ProtocolError => e
      warn "error: download failed: #{e.class}: #{e.message}"
      false
    end

    # Unpacks ZIP into DIR and refuses entries that try to escape it.
    # Warns and returns false on any failure.
    def extract(zip, dir)
      require "zip"
      Zip::File.open(zip) do |archive|
        archive.each do |entry|
          unless safe_entry_target(dir, entry.name)
            warn "error: zip entry escapes the install dir: #{entry.name}"
            return false
          end
          entry.extract(entry.name, destination_directory: dir,
            create_parent_directories: true)
        end
      end
      true
    rescue SystemCallError, Zip::Error => e
      warn "error: unpack failed: #{e.class}: #{e.message}"
      false
    end

    # The path to write zip entry NAME into, or nil when NAME escapes
    # DIR. A download is untrusted input: this is the zip-slip
    # guard.
    def safe_entry_target(dir, name)
      target = File.expand_path(File.join(dir, name))
      base = File.expand_path(dir) + File::SEPARATOR
      target.start_with?(base) ? target : nil
    end

    # One gem version pins one LanguageTool version. Older dirs are
    # hundreds of MB each, so delete them on every setup run and keep
    # only the current version (and any zips: they are re-deleted or
    # re-extracted by their own flow).
    def remove_stale_versions(dir, keep)
      require "fileutils"
      Dir.glob(File.join(dir, "LanguageTool-*")).each do |entry|
        FileUtils.rm_rf(entry) if File.directory?(entry) && entry != keep
      end
    end

    # Proves the installation works end to end: java runs the
    # commandline jar and the custom rules load. The command exits
    # nonzero on a broken java, a corrupt jar, or invalid rules XML,
    # so setup can report a real verdict instead of "files exist".
    # Returns a boolean, never raises or warns: the caller owns the
    # message.
    def smoke(install)
      rule = rule_ids.first
      return false if rule.nil?
      require "tmpdir"
      Dir.mktmpdir do |dir|
        text = File.join(dir, "smoke.txt")
        File.write(text, "Check this sentence.\n")
        system(install.java!, "-jar", install.commandline_jar,
          "--language", "en", "--rulefile", RULES_FILE,
          "--enable", rule, "--enabledonly", text,
          out: File::NULL, err: File::NULL) ? true : false
      end
    end

    # All rule IDs in RULES_FILE plus any extra rule files. Order is
    # stable: the built-in rules load first, user rules follow in config
    # order, duplicates drop. The id attribute may sit anywhere in the
    # tag: XML attribute order is free.
    def rule_ids(paths = [RULES_FILE])
      Array(paths).flat_map do |path|
        File.read(path).scan(/<rule(?:group)?\b[^>]*\bid=(["'])(\w+)\1/)
          .map { |_, id| id }
      end.uniq
    end
  end
end
