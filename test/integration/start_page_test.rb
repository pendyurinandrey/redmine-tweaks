# frozen_string_literal: true

# Feature "start page" (see lib/redmine_tweaks/welcome_controller_patch.rb): `/` sends a logged-in user to "My page".
# Ported from test/start_page_smoke.sh, which this replaces.
require_relative '../../../../test/test_helper'

class RedmineTweaks::StartPageTest < Redmine::IntegrationTest
  def setup
    @user = User.generate!(:password => 'Start-Page-Test-2026', :password_confirmation => 'Start-Page-Test-2026')
  end

  def test_anonymous_with_login_required_is_sent_to_the_login_page
    with_settings :login_required => '1' do
      get '/'
      assert_response :redirect
      assert_match %r{\A/login(\?|\z)}, @response.redirect_url.sub(%r{\Ahttps?://[^/]+}, '')
    end
  end

  def test_anonymous_without_login_required_sees_the_ordinary_home_page
    with_settings :login_required => '0' do
      get '/'
      assert_response :success
    end
  end

  def test_logged_in_user_is_redirected_from_the_root_to_my_page
    log_user(@user.login, 'Start-Page-Test-2026')

    get '/'
    assert_redirected_to '/my/page'

    get '/my/page'
    assert_response :success
  end

  def test_a_user_who_must_change_their_password_still_goes_there_first
    @user.update_column(:must_change_passwd, true)
    log_user(@user.login, 'Start-Page-Test-2026')

    get '/'
    assert_redirected_to '/my/password'
  end

  def test_robots_txt_is_not_affected
    get '/robots.txt'
    assert_response :success
  end
end
