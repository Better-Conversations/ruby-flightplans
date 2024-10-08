# frozen_string_literal: true

require "json"
require "json/add/struct"
require "tilt"
require "tilt/erb"
require "redcarpet"
require "tmpdir"
require "tempfile"
require "date"
require "open3"
require "securerandom"
require "pathname"
require "dry-struct"

# This is used by the validation code, it is not a mistake
require "rspec"

module BCF
  module FlightPlans
    GEM_ROOT = Pathname.new(__FILE__).join("../../..").expand_path

    def self.define_course(title, modules)
      Course.new(title, modules)
    end

    class Course
      attr_accessor :title
      attr_accessor :modules

      def initialize(title, modules)
        @title = title
        @modules = modules
      end

      def children
        modules
      end
    end

    module Types
      include Dry.Types()
    end

    class Error < StandardError; end

    class TypstMissingError < Error
      def initialize
        super("Typst is required to render flight plans to PDF. See https://github.com/typst/typst for instructions.")
      end
    end

    class TypstCompileError < Error
      attr_accessor :stdout
      attr_accessor :stderr
      attr_accessor :exit_code
      attr_accessor :typst_source

      def initialize(stdout, stderr, exit_code, typst_source)
        super("Typst compile failed with stderr: #{stderr}")

        @stdout = stdout
        @stderr = stderr
        @exit_code = exit_code
        @typst_source = typst_source
      end
    end

    class ValidationError < Error
    end
  end
end

require_relative "flight_plans/version"
require_relative "flight_plans/models"
require_relative "flight_plans/json"
require_relative "flight_plans/renderer"
require_relative "flight_plans/dsl"
require_relative "flight_plans/migrations"
require_relative "flight_plans/validation"
