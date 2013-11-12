module Elasticsearch
  module Model
    module Adapter
      module ActiveRecord

        Adapter.register self,
                         lambda { |klass| defined?(::ActiveRecord::Base) && klass.ancestors.include?(::ActiveRecord::Base) }

        module Records

          # Return the `ActiveRecord::Relation` instance
          #
          def records
            sql_records = klass.where(id: @ids)

            # Re-order records based on the order from Elasticsearch hits
            # by redefining `to_a`, unless the user has called `order()`
            #
            sql_records.instance_exec(response['hits']['hits']) do |hits|
              define_singleton_method :to_a do
                self.load
                @records.sort_by { |record| hits.index { |hit| hit['_id'] == record.id.to_s } }
              end
            end

            sql_records
          end

          # Prevent clash with `ActiveSupport::Dependencies::Loadable`
          #
          def load
            records.load
          end

          # Intercept call to order, so we can ignore the order from Elasticsearch
          #
          def order(*args)
            sql_records = records.__send__ :order, *args

            # Redefine the `to_a` method to the original one
            #
            sql_records.instance_exec do
              define_singleton_method(:to_a) { self.load; @records }
            end

            sql_records
          end
        end

        module Callbacks
          def self.included(base)
            base.class_eval do
              after_commit lambda { __elasticsearch__.index_document  },  on: [:create]
              after_commit lambda { __elasticsearch__.update_document },  on: [:update]
              after_commit lambda { __elasticsearch__.delete_document },  on: [:destroy]
            end
          end
        end

      end

    end
  end
end
