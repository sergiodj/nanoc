# frozen_string_literal: true

module Nanoc::Helpers
  # @see http://nanoc.ws/doc/reference/helpers/#breadcrumbs
  module Breadcrumbs
    class AmbiguousAncestorError < Nanoc::Int::Errors::Generic
      def initialize(pattern, items)
        @pattern = pattern
        @items = items
      end

      def message
        "expected only one item to match #{@pattern}, but found #{@items.size}"
      end
    end

    # @api private
    module Int
      DEFAULT_TIEBREAKER =
        lambda do |pattern, items|
          raise AmbiguousAncestorError.new(pattern, items)
        end

      # e.g. unfold(10.class, &:superclass)
      # => [Integer, Numeric, Object, BasicObject]
      def self.unfold(obj, &blk)
        acc = [obj]

        res = yield(obj)
        if res
          acc + unfold(res, &blk)
        else
          acc
        end
      end

      # e.g. patterns_for_prefix('/foo/1.0')
      # => ['/foo/1.0.*', '/foo/1.*']
      def self.patterns_for_prefix(prefix)
        prefixes =
          unfold(prefix) do |old_prefix|
            new_prefix = Nanoc::Identifier.new(old_prefix).without_ext
            new_prefix == old_prefix ? nil : new_prefix
          end

        prefixes.map { |pr| pr + '.*' }
      end

      def self.find_one(items, pat, tiebreaker)
        res = items.find_all(pat)
        case res.size
        when 0
          nil
        when 1
          res.first
        else
          tiebreaker.call(pat, res)
        end
      end
    end

    # @return [Array]
    def breadcrumbs_trail(tiebreaker: Int::DEFAULT_TIEBREAKER)
      # The design of this function is a little complicated.
      #
      # We can’t use #parent_of from the ChildParent helper, because the
      # breadcrumb trail can have gaps. For example, the breadcrumbs trail for
      # /software/oink.md might be /index.md -> nil -> /software/oink.md if
      # there is no item matching /software.* or /software/index.*.
      #
      # What this function does instead is something more complicated:
      #
      # 1.  It creates an ordered prefix list, based on the identifier of the
      #     item to create a breadcrumbs trail for. For example,
      #     /software/oink.md might have the prefix list
      #     ['', '/software', '/software/oink.md'].
      #
      # 2.  For each of the elements in that list, it will create a list of
      #     patterns could match zero or more items. For example, the element
      #     '/software' would correspond to the pattern '/software.*'.
      #
      # 3.  For each of the elements in that list, and for each pattern for that
      #     element, it will find any matching element. For example, the
      #     pattern '/software.*' (coming from the prefix /software) would match
      #     the item /software.md.
      #
      # 4.  Return the list of items, with the last element replaced by the item
      #     for which the breadcrumb is generated for -- while ancestral items
      #     in the breadcrumbs trail can have a bit of ambiguity, the item for
      #     which to generate the breadcrumbs trail is fixed.

      # e.g. ['', '/foo', '/foo/bar']
      components = item.identifier.components
      prefixes = components.inject(['']) { |acc, elem| acc + [acc.last + '/' + elem] }

      if @item.identifier.legacy?
        prefixes.map { |pr| @items[Nanoc::Identifier.new('/' + pr, type: :legacy)] }
      else
        ancestral_prefixes = prefixes.reject { |pr| pr =~ /^\/index\./ }[0..-2]
        ancestral_items =
          ancestral_prefixes.map do |pr|
            if pr == ''
              @items['/index.*']
            else
              prefix_patterns = Int.patterns_for_prefix(pr)
              prefix_patterns.lazy.map { |pat| Int.find_one(@items, pat, tiebreaker) }.find(&:itself)
            end
          end
        ancestral_items + [item]
      end
    end
  end
end
