module ASModel
  module ChangeTracking
    # ANW-617
    # These methods are copy-pasted from the Sequel Dirty plugin.

    # Unfortunately, simply enabling the plugin as per the Sequel docs breaks other code (saving agent relationships with a date), due to the after_save hook the plugin re-defines.

    # So, we introduce the code necessary to support the column_changed? method we need.

    # A hash of previous changes before the object was
    # saved, in the same format as #column_changes.
    # Note that this is not necessarily the same as the columns
    # that were used in the update statement.
    attr_reader :previous_changes

    # An array with the initial value and the current value
    # of the column, if the column has been changed.  If the
    # column has not been changed, returns nil.
    #
    #   column_change(:name) # => ['Initial', 'Current']
    def column_change(column)
      [initial_value(column), get_column_value(column)] if column_changed?(column)
    end

    # A hash with column symbol keys and pairs of initial and
    # current values for all changed columns.
    #
    #   column_changes # => {:name => ['Initial', 'Current']}
    def column_changes
      h = {}
      initial_values.each do |column, value|
        h[column] = [value, get_column_value(column)]
      end
      h
    end

    # Either true or false depending on whether the column has
    # changed.  Note that this is not exactly the same as checking if
    # the column is in changed_columns, if the column was not set
    # initially.
    #
    #   column_changed?(:name) # => true
    def column_changed?(column)
      initial_values.has_key?(column)
    end

    # Freeze internal data structures
    def freeze
      initial_values.freeze
      missing_initial_values.freeze
      @previous_changes.freeze if @previous_changes
      super
    end

    # The initial value of the given column.  If the column value has
    # not changed, this will be the same as the current value of the
    # column.
    #
    #   initial_value(:name) # => 'Initial'
    def initial_value(column)
      initial_values.fetch(column){get_column_value(column)}
    end

    # A hash with column symbol keys and initial values.
    #
    #   initial_values # {:name => 'Initial'}
    def initial_values
      @initial_values ||= {}
    end

    # Reset the column to its initial value.  If the column was not set
    # initial, removes it from the values.
    #
    #   reset_column(:name)
    #   name # => 'Initial'
    def reset_column(column)
      if initial_values.has_key?(column)
        set_column_value(:"#{column}=", initial_values[column])
      end
      if missing_initial_values.include?(column)
        values.delete(column)
      end
    end

    # Manually specify that a column will change.  This should only be used
    # if you plan to modify a column value in place, which is not recommended.
    #
    #   will_change_column(:name)
    #   name.gsub(/i/i, 'o')
    #   column_change(:name) # => ['Initial', 'onotoal']
    def will_change_column(column)
      changed_columns << column unless changed_columns.include?(column)
      check_missing_initial_value(column)

      value = if initial_values.has_key?(column)
        initial_values[column]
      else
        get_column_value(column)
      end

      initial_values[column] = if value && value != true && value.respond_to?(:clone)
        begin
          value.clone
        rescue TypeError
          value
        end
      else
        value
      end
    end

    private

    # Reset the initial values when setting values.
    def _refresh_set_values(hash)
      reset_initial_values
      super
    end

    # When changing the column value, save the initial column value.  If the column
    # value is changed back to the initial value, update changed columns to remove
    # the column.
    def change_column_value(column, value)
      if (iv = initial_values).has_key?(column)
        initial = iv[column]
        super
        if value == initial
          changed_columns.delete(column) unless missing_initial_values.include?(column)
          iv.delete(column)
        end
      else
        check_missing_initial_value(column)
        iv[column] = get_column_value(column)
        super
      end
    end

    # If the values hash does not contain the column, make sure missing_initial_values
    # does so that it doesn't get deleted from changed_columns if changed back,
    # and so that resetting the column value can be handled correctly.
    def check_missing_initial_value(column)
      unless values.has_key?(column) || (miv = missing_initial_values).include?(column)
        miv << column
      end
    end

    # Duplicate internal data structures
    def initialize_copy(other)
      super
      @initial_values = other.initial_values.dup
      @missing_initial_values = other.send(:missing_initial_values).dup
      @previous_changes = other.previous_changes.dup if other.previous_changes
      self
    end

    # Reset the initial values when initializing.
    def initialize_set(h)
      super
      reset_initial_values
    end

    # Array holding column symbols that were not present initially.  This is necessary
    # to differentiate between values that were not present and values that were
    # present but equal to nil.
    def missing_initial_values
      @missing_initial_values ||= []
    end

    # Clear the data structures that store the initial values.
    def reset_initial_values
      @initial_values.clear if @initial_values
      @missing_initial_values.clear if @missing_initial_values
    end

  end
end