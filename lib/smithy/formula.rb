module Smithy
  class Formula
    attr_accessor :package, :module_setup

    def initialize(args = {})
      if args[:package]
        @package = args[:package]
        @version = @package.version
        @name    = @package.name
        @prefix  = @package.prefix
      end

      @module_setup = ''

      if ENV['MODULESHOME']
        @module_setup << `#{@module_setup} #{ENV['MODULESHOME']}/bin/modulecmd sh purge`
        @module_setup << ' '
        if modules
          @module_setup << `#{@module_setup} #{ENV['MODULESHOME']}/bin/modulecmd sh load #{@modules.join(' ')}`
          @module_setup << ' '
        end
      end
    end

    def system(*args)
      notice args.join(' ')
      Kernel.system @module_setup + args.join(' ')
      if $?.exitstatus != 0
        raise <<-EOF.strip_heredoc
          The last command exited with status: #{$?.exitstatus}
            Formula: #{__FILE__}
            Build Directory: #{@package.source_directory}
        EOF
      end
    end

    def run_install
      install
      notice_success "SUCCESS #{@package.prefix}"
      return true
    end

    def module_list
      if ENV['MODULESHOME']
        notice "module list"
        Kernel.system @module_setup + "#{ENV['MODULESHOME']}/bin/modulecmd sh list 2>&1"
      end
    end

    # DSL and instance methods

    %w{url homepage md5 sha1 sha2 version name prefix modules}.each do |attr|
      class_eval %Q{
        def self.#{attr}(value = nil, &block)
          if block_given?
            @#{attr} = block
          elsif value
            @#{attr} = value
          end

          @#{attr}
        end

        def #{attr}
          unless @#{attr}
            if self.class.#{attr}.is_a?(Proc)
              @#{attr} = instance_eval(&self.class.#{attr})
            else
              @#{attr} = self.class.#{attr}
            end
          end

          @#{attr}
        end
      }
    end

  end #class Formula
end #module Smithy
