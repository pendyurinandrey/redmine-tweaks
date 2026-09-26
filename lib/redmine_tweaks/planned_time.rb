# frozen_string_literal: true

# Feature "planned time" widget for "My page": per-day sums of the estimated time of issues planned for exactly that day
# (start date = due date = the day). The view is app/views/my/blocks/_planned_time.html.erb (Redmine registers every
# partial there as a My page block).
module RedmineTweaks
  class PlannedTime
    MIN_DAYS = 7
    MAX_DAYS = 14
    DEFAULT_NORM = 8.0

    Day = Struct.new(:date, :hours, :count, :without_estimate, keyword_init: true)

    attr_reader :days, :assignee_id, :norm_hours

    # settings: the block's settings hash (values are strings, keys may be symbols or strings)
    def initialize(user, settings)
      settings = (settings || {}).to_h.symbolize_keys
      @user = user
      @days = settings[:days].to_i.clamp(MIN_DAYS, MAX_DAYS)
      @assignee_id = settings[:assignee_id].presence&.to_i
      @norm_enabled = settings[:norm_enabled].to_s != '0' # absent = on
      norm = settings[:norm_hours].to_s.tr(',', '.').to_f
      @norm_hours = norm.positive? ? [norm, 24.0].min : DEFAULT_NORM
    end

    def norm_enabled?
      @norm_enabled
    end

    def period
      @period ||= @user.today..(@user.today + days - 1)
    end

    # One Day per date of the period, in order
    def day_list
      @day_list ||= begin
        hours = same_day.where("#{issues}.estimated_hours > 0").group(:start_date).sum(:estimated_hours)
        counts = same_day.where("#{issues}.estimated_hours > 0").group(:start_date).count
        blank = same_day.where("#{issues}.estimated_hours IS NULL OR #{issues}.estimated_hours = 0").group(:start_date).count
        period.map do |date|
          Day.new(date: date, hours: hours[date].to_f, count: counts[date].to_i, without_estimate: blank[date].to_i)
        end
      end
    end

    # Height reference for the bars: the biggest day (or the norm line, when shown), at least 1 hour
    def scale_max
      @scale_max ||= [day_list.map(&:hours).max.to_f, norm_enabled? ? norm_hours : 0.0, 1.0].max
    end

    # Open issues that span several days and have an estimate: not counted in any bar (only start = due issues are)
    def multi_day
      @multi_day ||= begin
        scope = base.where("#{issues}.start_date <> #{issues}.due_date").
                     where("#{issues}.start_date <= ? AND #{issues}.due_date >= ?", period.end, period.begin).
                     where("#{issues}.estimated_hours > 0")
        { count: scope.count, hours: scope.sum(:estimated_hours).to_f }
      end
    end

    private

    def issues
      Issue.table_name
    end

    # Visible open issues, optionally of one assignee
    def base
      scope = Issue.visible(@user).open
      scope = scope.where(assigned_to_id: assignee_id) if assignee_id
      scope
    end

    def same_day
      base.where(start_date: period).where("#{issues}.due_date = #{issues}.start_date")
    end
  end
end
