# frozen_string_literal: true

# Feature "planned time": the block's settings form, rendering and links. Ported from test/planned_time_smoke.sh,
# which this replaces. The calculation itself is unit-tested in test/unit/planned_time_test.rb.
require_relative '../../../../test/test_helper'

class RedmineTweaks::PlannedTimeIntegrationTest < Redmine::IntegrationTest
  def setup
    @user = User.generate!(:password => 'Planned-Time-Test-2026', :password_confirmation => 'Planned-Time-Test-2026')
    log_user(@user.login, 'Planned-Time-Test-2026')
    post '/my/add_block', :params => {:block => 'planned_time'}
  end

  def test_the_block_and_its_settings_form_are_on_my_page
    get '/my/page'
    assert_select '#block-planned_time'
    assert_select '#planned_time-settings'
    assert_select 'div.rt-planned[data-rt-days="7"]', 1, 'the default is 7 days'
  end

  def test_number_of_days_1_to_14_and_clamping
    {'14' => 14, '10' => 10, '3' => 7, '99' => 14, 'abc' => 7}.each do |input, bars|
      save_settings(:days => input)
      get '/my/page'
      assert_select 'a.rt-col', bars, "days=#{input} should render #{bars} bar(s)"
    end
  end

  def test_norm_line_can_be_switched_off_and_accepts_a_decimal_comma
    save_settings(:norm_enabled => '1', :norm_hours => '8')
    get '/my/page'
    assert_select '.rt-norm', 1

    save_settings(:norm_enabled => '0')
    get '/my/page'
    assert_select '.rt-norm', 0

    save_settings(:norm_enabled => '1', :norm_hours => '6,5')
    get '/my/page'
    assert_select '.rt-norm[data-hours="6.5"]'

    save_settings(:norm_enabled => '1', :norm_hours => '-3')
    get '/my/page'
    assert_select '.rt-norm[data-hours="8.0"]', :count => 1 # a non-positive norm should fall back to 8
  end

  def test_a_bar_links_to_that_day_s_filtered_issue_list
    save_settings(:days => '7', :norm_enabled => '1', :norm_hours => '8')
    get '/my/page'
    link = css_select('a.rt-col').first['href']
    assert_match(/start_date/, link)
    assert_match(/due_date/, link)

    get link
    assert_response :success
  end

  private

  def save_settings(settings)
    post '/my/page', :params => {:settings => {:planned_time => settings}}, :xhr => true
    assert_response :success
  end
end
