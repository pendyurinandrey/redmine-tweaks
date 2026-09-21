# Feature "calendar weeks": the "Calendar" block of "My page" can show 1 to 5 weeks instead of the current week only.
# Idea and the original core patch: https://www.redmine.org/issues/26525
module RedmineTweaks
  module CalendarWeeks
    MIN = 1
    MAX = 5

    def self.weeks_from(settings)
      (settings && settings[:weeks]).to_i.clamp(MIN, MAX)
    end

    # Redmine::Helpers::Calendar: the period :week keeps meaning "the current week"; :week2 .. :week5 extend its end.
    module CalendarPatch
      def initialize(date, lang = current_language, period = :month)
        weeks = period.to_s[/\Aweek(\d+)\z/, 1]
        return super unless weeks
        super(date, lang, :week)
        @enddt += 7 * (weeks.to_i.clamp(MIN, MAX) - 1)
      end
    end

    # MyHelper: the block renderer reads the number of weeks from the block settings (the settings form is in the view override).
    module MyHelperPatch
      def render_calendar_block(block, settings)
        weeks = CalendarWeeks.weeks_from(settings)
        calendar = Redmine::Helpers::Calendar.new(User.current.today, current_language, :"week#{weeks}")
        calendar.events = Issue.visible.
          where(:project => User.current.projects).
          where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", calendar.startdt, calendar.enddt, calendar.startdt, calendar.enddt).
          includes(:project, :tracker, :priority, :assigned_to).
          references(:project, :tracker, :priority, :assigned_to).
          to_a

        render :partial => 'redmine_tweaks/calendar_weeks/calendar', :locals => {:calendar => calendar, :block => block, :weeks => weeks}
      end
    end
  end
end
