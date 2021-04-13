module Oscar
  class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
    def new_column_definition(name, type, options)
      if type == :integer && options[:limit].to_i > 0
        options[:limit] = 0
      end

      super(name.downcase, type, options)
    end
  end

  class SchemaCreation < ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      if type == :integer || type == :text
        super(type, nil, precision, scale)
      else
        super(type, limit, precision, scale)
      end
    end
  end
end
