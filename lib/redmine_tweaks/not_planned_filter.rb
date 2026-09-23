# Feature "not planned" issue filter: a "Not planned" filter on the issue list, for issues whose start date OR due
# date is missing (core filters can only be ANDed together, so this pair could not be expressed as two filters).
#
# Implemented as a single "virtual" filter field, the same extension point Redmine's own core uses for fields that
# are not a plain column (see IssueQuery#sql_for_is_private_field, #sql_for_parent_id_field for core examples):
# `initialize_available_filters` registers the field, and `sql_for_not_planned_field` supplies its SQL — free to
# combine start_date and due_date with OR, because Redmine only ANDs *separate* filters, not the SQL a single
# filter's own method returns.
module RedmineTweaks
  module NotPlannedFilter
    def initialize_available_filters
      super
      add_available_filter(
        'not_planned',
        :type => :list,
        :name => l(:field_tweaks_not_planned),
        :values => [[l(:general_text_Yes), '1'], [l(:general_text_No), '0']]
      )
    end

    def sql_for_not_planned_field(field, operator, value)
      unplanned = "(#{Issue.table_name}.start_date IS NULL OR #{Issue.table_name}.due_date IS NULL)"
      yes = value.include?('1')
      no  = value.include?('0')
      result =
        if yes && no  then '1=1'   # both "Yes" and "No" selected: no filtering
        elsif yes     then unplanned
        elsif no      then "NOT #{unplanned}"
        else               '1=0'  # nothing selected: matches nothing, same as core's own empty-value filters
        end
      operator == '!' ? "NOT (#{result})" : result
    end
  end
end
