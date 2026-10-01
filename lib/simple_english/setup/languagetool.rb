# frozen_string_literal: true

# The pinned LanguageTool distro: its version, its rules file, and the
# downloader. Everything that resolves "where it is on this machine and
# which java runs it" lives in Install. The engine runs as the daemon's
# inner HTTP server (lib/simple_english/daemon/server.rb).

module SimpleEnglish
  module LanguageTool
    RULES_FILE = File.expand_path("../../../rules/simple-english.xml", __dir__)
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
    # returns {"dir" => install dir, "downloaded" => bool} so `se setup`
    # can say what it found and what it fetched, or nil after warning
    # why. Pure Ruby throughout: the download uses Net::HTTP and the
    # unpack parses the zip with stdlib Zlib, so setup needs no curl,
    # unzip, or unpack gem on the machine.
    def install(dir)
      require "fileutils"
      dest = File.join(dir, "LanguageTool-#{LT_VERSION}")
      if File.exist?(File.join(dest, "languagetool-commandline.jar"))
        remove_stale_versions(dir, dest)
        return {"dir" => dest, "downloaded" => false}
      end
      zip = File.join(dir, "LanguageTool-#{LT_VERSION}.zip")
      FileUtils.mkdir_p(dir)
      return nil unless download(download_url, zip)
      return nil unless extract(zip, dir)
      File.delete(zip)
      remove_stale_versions(dir, dest)
      {"dir" => dest, "downloaded" => true}
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

    # Unpacks ZIP into DIR on stdlib Zlib: the End of Central Directory
    # record locates the central directory, each entry names a local
    # header, and each stream inflates raw. The input is the one pinned
    # LanguageTool distro, not arbitrary archives, so zip64 (4 GB+ or
    # 65,535+ entries) is refused, not parsed. Warns and returns false
    # on any failure.
    def extract(zip, dir)
      require "fileutils"
      require "zlib"
      bytes = File.binread(zip)
      tail = eocd(bytes)
      raise Zlib::DataError, "not a zip archive" if tail.nil?
      count, cd_offset = tail
      pos = cd_offset
      count.times do
        name, method, csize, crc, local, pos = cd_entry(bytes, pos)
        raise Zlib::DataError, "corrupt central directory" if name.nil?
        next if name.end_with?("/")
        target = safe_entry_target(dir, name)
        if target.nil?
          warn "error: zip entry escapes the install dir: #{name}"
          return false
        end
        data_at = local_data_offset(bytes, local)
        raise Zlib::DataError, "corrupt local header" if data_at.nil?
        data = inflate_entry(bytes.byteslice(data_at, csize), method)
        raise Zlib::DataError, "CRC mismatch: #{name}" unless Zlib.crc32(data) == crc
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, data)
      end
      true
    rescue Zlib::Error, SystemCallError => e
      warn "error: unpack failed: #{e.class}: #{e.message}"
      false
    end

    # The End of Central Directory record: the entry count and the
    # central directory offset, or nil. The record ends the archive,
    # possibly behind a comment of at most 65,535 bytes, so the scan
    # starts at the tail. Zip64 sentinels are refused: the pinned
    # distro is far under the limits.
    def eocd(bytes)
      limit = [bytes.bytesize, 65_557].min
      window = bytes.byteslice(bytes.bytesize - limit, limit)
      at = window.rindex("PK\x05\x06")
      return nil if at.nil?
      rec = window.byteslice(at, 22)
      return nil if rec.bytesize < 22
      count = rec.byteslice(10, 2).unpack1("v")
      cd = rec.byteslice(16, 4).unpack1("V")
      return nil if count == 0xFFFF || cd == 0xFFFFFFFF
      [count, cd]
    end

    # One central-directory record at POS: the entry name,
    # compression method, compressed size, CRC-32, local header
    # offset, and the offset of the next record. nil when the record
    # is truncated or unsigned.
    def cd_entry(bytes, pos)
      head = bytes.byteslice(pos, 46)
      return nil unless head.byteslice(0, 4) == "PK\x01\x02" && head.bytesize == 46
      name_len = head.byteslice(28, 2).unpack1("v")
      name = bytes.byteslice(pos + 46, name_len)
      [name,
        head.byteslice(10, 2).unpack1("v"),
        head.byteslice(20, 4).unpack1("V"),
        head.byteslice(16, 4).unpack1("V"),
        head.byteslice(42, 4).unpack1("V"),
        pos + 46 + name_len + head.byteslice(30, 2).unpack1("v") +
          head.byteslice(32, 2).unpack1("v")]
    end

    # Where an entry's data sits: the local header at OFFSET names
    # its own name and extra lengths, and the data follows them. nil
    # when the header is truncated or unsigned.
    def local_data_offset(bytes, offset)
      head = bytes.byteslice(offset, 30)
      return nil unless head.byteslice(0, 4) == "PK\x03\x04" && head.bytesize == 30
      offset + 30 + head.byteslice(26, 2).unpack1("v") +
        head.byteslice(28, 2).unpack1("v")
    end

    # One entry's bytes: STORED is copied, DEFLATE is inflated raw.
    def inflate_entry(blob, method)
      return blob if method.zero?
      return Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(blob) if method == 8
      raise Zlib::DataError, "unsupported compression method #{method}"
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

    # All rule IDs in RULES_FILE, in document order. The tag scan pairs each opening rule or rulegroup
    # tag with the id attribute inside it, so attribute order never
    # matters. It reads the repo's own file, which the test suite
    # round-trips through LanguageTool, so malformed XML fails the
    # build, not the boot. The daemon's enabledRules parameter on
    # every lint request needs this list. A rule LT loads but the
    # list omits is dead, because enabledOnly is set.
    # examples_check asserts this list against a real XML parser,
    # and LT itself rejects duplicate ids at load, so no dedup is
    # needed here.
    def rule_ids(path = RULES_FILE)
      # Explicit UTF-8: the file holds non-ASCII bytes, and a bare
      # File.read uses the process's external encoding. Under
      # launchd that is US-ASCII, and the scan below dies on the
      # first such byte. The daemon must boot in any locale.
      File.read(path, encoding: "UTF-8").scan(/<(?:rule|rulegroup)\b[^>]*>/).filter_map do |tag|
        tag[/\bid="([^"]+)"/, 1]
      end
    end
  end
end
