module BCF
  module FlightPlans
    module ValidationSubject
      def children
        raise NotImplementedError
      end
    end

    class Validator
      def initialize(root, validators)
        @root = root
        @validators = validators
        @errors = []
      end

      def is_valid?
        validate_node(@root)
        @errors.empty?
      end

      attr_reader :errors

      private

      def validate_node(node)
        @validators.select { _1.should_apply?(node) }.each do |validation|
          errors = validation.validate(node)
          @errors << errors if errors
        end

        node.children.each { validate_node(_1) }
      end
    end

    module Validation
      include ::RSpec::Matchers

      def should_apply?(subject)
        raise NotImplementedError
      end

      def perform(subject)
        validate(subject)
      rescue RSpec::Expectations::ExpectationNotMetError => e
        e
      end

      def validate(subject)
        raise NotImplementedError
      end
    end

    class LengthValidation
      def should_apply?(subject)
        subject.is_a?(FlightPlan)
      end

      def validate(subject)
        expect(subject.blocks.map(&:length).sum).to eq(subject.total_length)
      end
    end
  end
end
