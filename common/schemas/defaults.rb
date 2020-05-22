locale_enum = I18n.supported_locales.keys

column_opts_file = File.join(ASUtils.find_base_directory("common"), "config", "search_browse_column_config.rb")
column_opts = eval(File.read(column_opts_file))

ASUtils.find_local_directories("search_browse_column_plugin_config.rb").each do |file|
  if File.exist?(file)
    plugin_column_opts = eval(File.read(File.absolute_path(file))) 
    plugin_column_opts.each do |type, cols|
      column_opts[type] = column_opts[type].merge(cols)
    end
  end
end

browse_columns = {}
column_opts.keys.each do |type|
  Array(1..AppConfig[:max_search_columns]).each do |i|
    browse_columns["#{type}_browse_column_#{i}"] = {
      "type" => "string",
      "enum" => column_opts[type].collect { |col, _opts| col } + ['no_value'],
      "required" => false
    }
  end
  browse_columns["#{type}_sort_column"] = {
    "type" => "string",
    "enum" => (column_opts[type].collect { |col, opts| 
      opts[:sortable] ? (!opts[:sort].is_a?(Array) ? col: opts[:sort]) : nil }.flatten.compact + 
      ['no_value']),
    "required" => false
  }
  browse_columns["#{type}_sort_direction"] = {
    "type" => "string",
    "enum" => ['asc', 'desc'],
    "required" => false
  }
end

{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {

      "show_suppressed" =>  {
        "type" => "boolean",
        "required" => false,
        "default" => false
      },

      "publish" => {
        "type" => "boolean",
        "required" => false,
        "default" => false
      },

      "locale" => {
        "type" => "string",
        "enum" => locale_enum,
        "required" => false
      },

      "default_values" => {
        "type" => "boolean",
        "required" => false,
        "default" => false
      },

      "note_order" => {
        "type" => "array",
        "items" => {"type" => "string"}
      }

    }.merge(browse_columns),
  },
}
