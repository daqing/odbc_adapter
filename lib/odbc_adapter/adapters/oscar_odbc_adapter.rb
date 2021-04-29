ActiveRecord::AttributeSet.class_eval do
  def [](name)
    name = 'id' if name == 'ID'

    attributes[name] || Attribute.null(name)
  end
end

module ODBCAdapter
  module Adapters
    class OSCARODBCAdapter < ActiveRecord::ConnectionAdapters::ODBCAdapter
      PRIMARY_KEY = 'INT NOT NULL AUTO_INCREMENT PRIMARY KEY'.freeze

      def add_column(table_name, column_name, type, options={})
        execute("ALTER TABLE #{table_name} ADD COLUMN #{column_name.downcase} #{type_to_sql(type)}")
      end

      def prepared_statements
        false
      end

      def truncate(table_name, name = nil)
        execute("TRUNCATE TABLE #{quote_table_name(table_name)}", name)
      end

      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      # def quote_string(string)
      # end

      def quoted_true
        '1'
      end

      def unquoted_true
        1
      end

      def quoted_false
        '0'
      end

      def unquoted_false
        0
      end

      def _quote(value)
        case value
        when Date, Time then quoted_date(value)
        else
          if value.is_a?(String) && value.start_with?('from_tz')
            return value
          end

          super(value)
        end
      end

      def quoted_date(value)
        str = value.strftime("%Y-%m-%d %H:%M:%S")
        %(from_tz('#{str}', '+08:00'))
      end

      def disable_referential_integrity(&_block)
        old = select_value('SELECT @@FOREIGN_KEY_CHECKS')

        begin
          update('SET FOREIGN_KEY_CHECKS = 0')
          yield
        ensure
          update("SET FOREIGN_KEY_CHECKS = #{old}")
        end
      end

      def supports_migrations?
        true
      end

      def create_database(name, options = {})
        if options[:collation]
          execute("CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}` COLLATE `#{options[:collation]}`")
        else
          execute("CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}`")
        end
      end

      def drop_database(name)
        execute("DROP DATABASE IF EXISTS `#{name}`")
      end

      def create_table(name, options = {})
        super(name, options)
      end

      def create_table_definition(*args) # :nodoc:
        ::Oscar::TableDefinition.new(*args)
      end

      def schema_creation
        ::Oscar::SchemaCreation.new(self)
      end

      # Renames a table.
      def rename_table(name, new_name)
        execute("ALTER TABLE #{quote_table_name(name)} RENAME TO #{quote_table_name(new_name)}")
      end

      def change_column(table_name, column_name, type, options = {})
        if type == :text
          options[:limit] = nil
        end

        unless options_include_default?(options)
          options[:default] = column_for(table_name, column_name).default
        end

        # change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        # add_column_options!(change_column_sql, options)
        execute(change_column_sql)
      end

      def change_column_default(table_name, column_name, default_or_changes)
        default = extract_new_default_value(default_or_changes)
        column = column_for(table_name, column_name)

	# FIXME: 单独实现此方法，不用调用 change_column
        # change_column(table_name, column_name, column.sql_type, default: default)
      end

      def change_column_null(table_name, column_name, null, default = nil)
        column = column_for(table_name, column_name)

        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
	
	# FIXME: 增加对应的修改语句
      end

      def add_index(table_name, column_name, options={})
        if column_name.is_a?(Array)
          cols = column_name.map(&:downcase)
        else
          cols = column_name.downcase
	end

        super(table_name, cols, options)
      end

      def remove_index(table_name, column_name, options={})
        index_name = options[:name] ? options[:name] : "index_#{table_name}_on_#{column_name}"
        execute("DROP INDEX #{index_name}")
      end

      def format_case(identifier)
        identifier.downcase
      end

      def rename_column(table_name, column_name, new_column_name)
        column = column_for(table_name, column_name)
        current_type = column.native_type
        # current_type << "(#{column.limit})" if column.limit
        execute("ALTER TABLE #{table_name} RENAME COLUMN #{column_name} TO #{new_column_name}")
      end

      # Skip primary key indexes
      def indexes(table_name, name = nil)
        super(table_name, name).reject { |i| i.unique && i.name =~ /^PRIMARY$/ }
      end

      def options_include_default?(options)
        if options.include?(:default) && options[:default].nil?
          if options.include?(:column) && options[:column].native_type =~ /timestamp/i
            options.delete(:default)
          end
        end
        super(options)
      end

      def last_inserted_id(_value)
        select_value('SELECT LAST_INSERT_ID()').to_i
      end

      def release_savepoint(name = "")
        execute("DROP SAVEPOINT #{name}")
      end
    end
  end
end
