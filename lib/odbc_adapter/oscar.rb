class ActiveRecord::Attribute
  alias_method :origin_value, :value

  def value
    v = origin_value
    if v.is_a?(String) && !v.frozen?
      v.force_encoding('utf-8')
      v = v.scrub('') unless v.valid_encoding?
    end
    v
  end
  
end

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
