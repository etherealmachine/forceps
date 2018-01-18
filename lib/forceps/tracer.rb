require "forceps/utils"
require 'graphviz'

module Forceps
	class MaxLevelReachedError < StandardError; end

	class Tracer
    include Forceps::Utils
		attr_accessor :options, :level, :nodes, :edges, :exceptions

		def initialize(options)
			@options = options
			@level = 0
			@nodes = Set.new
			@edges = Hash.new { |h, k| h[k] = Hash.new }
			@exceptions = []
		end

		def trace(remote_class)
			with_new_level do
				[:belongs_to, :has_one, :has_many, :has_and_belongs_to_many].each do |association_kind|
					follow_objects_associated_by_association_kind(remote_class, association_kind) if remote_class
				end
			end
		end

		def as_graph
			g = GraphViz.new(:G, :type => :digraph)
			@edges.each do |parent, children|
				children.each do |child, edge|
					association_kind, association = edge
					parent_name = to_local_class_name(parent.name)
					child_name = to_local_class_name(child.name)
					g.add_nodes(parent_name)
					g.add_nodes(child_name)
					g.add_edges(parent_name, child_name, :label => "#{association_kind}")
				end
			end
			@exceptions.each do |remote_class, association, association_kind, exception|
				next if exception.is_a? MaxLevelReachedError
				g.add_edges(to_local_class_name(remote_class.name), association.class_name, :label => "Exception: #{association_kind}")
			end
			g
		end

		def with_new_level
			@level += 1
			if options[:max_level] and level >= options[:max_level]
				raise MaxLevelReachedError
			end
			yield
			@level -= 1
		end

		def add_association(parent, association, association_kind)
			@nodes.add(parent)
			@nodes.add(association.klass)

			@edges[parent][association.klass] = [association_kind, association]
		end

		def has_association(parent, association, association_kind)
			return @edges[parent][association.klass]
		end

		def follow_objects_associated_by_association_kind(remote_class, association_kind)
			return if options.fetch(:ignore_model, []).include?(remote_class.base_class.name)
			associations = Forceps.associations_to_follow(remote_class, association_kind)
			associations.each do |association|
				begin
					next if has_association(remote_class, association, association_kind)
					add_association(remote_class, association, association_kind)
					case association_kind
					when :has_many, :has_one, :has_and_belongs_to_many
						trace(association.klass)
					when :belongs_to
						with_new_level do
							Forceps.associations_to_follow(remote_class, :belongs_to).each do |association|
								next if has_association(remote_class, association, :belongs_to)
								trace(association.klass)
							end
						end
					end
				rescue Exception => e
					@exceptions << [remote_class, association, association_kind, e]
				end
			end
		end

	end