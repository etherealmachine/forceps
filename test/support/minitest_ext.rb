module Minitest
  module Assertions
    # Compares the equality at the attribute level
    def assert_identical expected, actual, msg = nil
      actual = actual.becomes(expected.class) if actual && actual.class != expected.class
      ignored_attributes = %w(id)
      if not expected.respond_to? :attributes or not actual.respond_to? :attributes
        assert_equal expected, actual
        return
      end
      want = expected.attributes.except(*ignored_attributes)
      got = actual.attributes.except(*ignored_attributes)
      if not want.respond_to? :to_s or not got.respond_to? :to_s
        assert_equal want, got
        return
      end

      assert_equal want.to_s, got.to_s
    end
  end
end

