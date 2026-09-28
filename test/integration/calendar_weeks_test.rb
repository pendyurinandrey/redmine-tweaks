# frozen_string_literal: true

# Feature "calendar weeks" (see lib/redmine_tweaks/calendar_weeks.rb): the Calendar block of "My page" shows 1 to 5
# weeks. Ported from test/calendar_weeks_smoke.sh, which this replaces.
require_relative '../../../../test/test_helper'

class RedmineTweaks::CalendarWeeksTest < Redmine::IntegrationTest
  def setup
    @user = User.generate!(:password => 'Calendar-Weeks-Test-2026', :password_confirmation => 'Calendar-Weeks-Test-2026')
    log_user(@user.login, 'Calendar-Weeks-Test-2026')
    post '/my/add_block', :params => {:block => 'calendar'}
  end

  def test_the_block_and_its_settings_form_are_on_my_page
    get '/my/page'
    assert_select '#block-calendar'
    assert_select '#calendar-settings'
  end

  def test_number_of_weeks_1_to_5
    (1..5).each do |n|
      set_weeks(n)
      get '/my/page'
      assert_select '.label-week', n, "weeks=#{n} should render #{n} week row(s)"
      assert_select 'select#calendar-weeks option[selected][value=?]', n.to_s
    end
  end

  def test_out_of_range_values_are_clamped
    set_weeks(9)
    get '/my/page'
    assert_select '.label-week', 5, 'weeks=9 should clamp to 5'

    set_weeks(0)
    get '/my/page'
    assert_select '.label-week', 1, 'weeks=0 should clamp to 1'

    set_weeks('abc')
    get '/my/page'
    assert_select '.label-week', 1, 'a non-numeric value should fall back to 1'
  end

  private

  def set_weeks(n)
    post '/my/page', :params => {:settings => {:calendar => {:weeks => n}}}, :xhr => true
    assert_response :success
  end
end
