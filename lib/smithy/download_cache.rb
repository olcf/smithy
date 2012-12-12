module Smithy
  class DownloadCache
    attr_accessor :url, :name, :version, :checksums

    def initialize(p)
      if p.is_a? Formula
        @url = p.try(:url)
        @checksums = {}
        @checksums.merge!(:md5 => p.md5) if p.try(:md5)
        @checksums.merge!(:sha1 => p.sha1) if p.try(:sha1)
        @name = p.try(:package).try(:name)
        @version = p.try(:package).try(:version)
      else
        return nil
      end
    end

    def downloaded_file_name
      File.basename(URI(url).path)
    end

    def downloaded_file_dir
      dir = Smithy::Config.global[:"download-cache"]
      dir = File.join(ENV['HOME'], '.smithy/cache') if dir.blank?
      File.join(dir, name, version)
    end

    def downloaded_file_path
      File.join(downloaded_file_dir, downloaded_file_name)
    end

    def downloaded?
      File.exists?(downloaded_file_path)
    end

    def checksum_download
      return false unless downloaded?

      checksums.keys.each do |type|
        checksum = checksums[type]
        digest = ''
        case type
        when :md5
          require 'digest/md5'
          digest = Digest::MD5.hexdigest(File.read(downloaded_file_path))
        when :sha1
          require 'digest/sha1'
          digest = Digest::SHA1.hexdigest(File.read(downloaded_file))
        end

        if checksum != digest
          raise <<-EOF.strip_heredoc
            file does not match expected #{type.to_s.upcase} checksum
                   expected: #{checksum}
                   got:      #{digest}
          EOF
        end
      end
    end

    def download
      curl = '/usr/bin/curl'
      curl = `which curl` unless File.exist? curl
      raise "curl cannot be located, without it files cannot be downloaded" if curl.blank?

      if downloaded?
        puts "downloaded ".rjust(12).color(:green).bright + downloaded_file_path
        return true
      else
        puts "download ".rjust(12).color(:green).bright + url
      end

      args = ['-qf#L']
      args << "--silent" unless $stdout.tty?
      args << '-o'
      args << downloaded_file_path
      args << url

      FileUtils.mkdir_p downloaded_file_dir
      [downloaded_file_dir, File.join(downloaded_file_dir, '..')].each do |dir|
        FileOperations.set_group(dir, Smithy::Config.global[:"file-group-name"])
        FileOperations.make_group_writable(dir) unless Smithy::Config.global[:"disable-group-writable"]
      end

      if system(curl, *args)
        FileOperations.set_group(downloaded_file_path, Smithy::Config.global[:"file-group-name"])
        FileOperations.make_group_writable(downloaded_file_path) unless Smithy::Config.global[:"disable-group-writable"]
        return true
      else
        return false
      end
    end

    def get
      if download
        checksum_download
      end
    end

  end
end

