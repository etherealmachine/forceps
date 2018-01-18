module Forceps

  module Utils

    def to_local_class_name(remote_class_name)
      remote_class_name.gsub('Forceps::Remote::', '')
    end

    def attributes_to_exclude(remote_class)
      @attributes_to_exclude_map ||= {}
      @attributes_to_exclude_map[remote_class.base_class] ||= calculate_attributes_to_exclude(remote_class)
    end

    def calculate_attributes_to_exclude(remote_class)
      ((options[:exclude] && options[:exclude][remote_class.base_class]) || []).collect(&:to_sym)
    end

    def associations_to_follow(remote_class, association_kind)
      excluded_attributes = attributes_to_exclude(remote_class)
      remote_class.reflect_on_all_associations(association_kind).reject do |association|
        association.options[:through] ||
          excluded_attributes.include?(:all_associations) ||
          excluded_attributes.include?(association.name) ||
          (!association.options[:polymorphic] && options.fetch(:ignore_model, []).include?(to_local_class_name(association.klass.name)))
      end
    end

  end

end