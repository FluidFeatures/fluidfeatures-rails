[![Build Status](https://secure.travis-ci.org/FluidFeatures/fluidfeatures-rails.png)](http://travis-ci.org/FluidFeatures/fluidfeatures-rails)

Rails graceful feature rollout and simple A/B testing
=====================================================

`gem fluidfeatures-rails` is a Ruby on Rails client for the API of FluidFeatures.com, which provides an elegant way to wrap new code so you have real-time control over rolling out new features to your user-base.

Integration
-----------

Add the gem to your application's `Gemfile` and run `bundle update fluidfeatures-rails`

```ruby
gem "fluidfeatures-rails"
```

Add this line to your `config/application.rb`

```ruby
FluidFeatures::Rails.initializer
```

Add this `fluidfeature_current_user` method in your `ApplicationController`, where `current_user` returns your currently logged in user object.
See [User definition and cohorts](#user-definition-and-cohorts) for more details.

```ruby
def fluidfeatures_current_user(verbose=false)
  current_user ? { :id => current_user.id } : nil
end
```

Generate a `config/fluidfeatures.yml` config file by running

`rails g fluidfeatures:config`

This will prompt you for your app credentials which you can find on the [fluidfeatures.com/dashboard](https://www.fluidfeatures.com/dashboard) and are specific to each app you create.
Enter your `app_id` and `secret` for your `development` environment. You can skip the rest for now.

Start adding your features and goals using `if ff?` (or `if fluidfeature`) and `fluidgoal`.

In your controllers or your views...

```ruby
# "theme" is simply an example feature name, used to represent
# a migration to a styling of your website
if ff? "theme", "default"
  # wrap code related to your default theme, so it is
  # only executed when the user is allocated this version
  # of the feature "theme".
end
# Alternate verison of the "theme" feature.
# FluidFeatures will only assign a user to one version
# of a feature.
if ff? "theme", "tropical"
  # implement code specifically related to your new theme
end

fluidgoal "bought-bieber-dvd"

fluidgoal "added-a-comment"

fluidgoal "upgraded-to-pro-account"

fluidgoal "general-engagement"
```

Dashboard
---------

If you log into your FluidFeatures account and visit [fluidfeatures.com/dashboard](https://www.fluidfeatures.com/dashboard) you will see your feature and goal dashboard.

![Example dashboard view](http://commondatastorage.googleapis.com/philwhln/blog/images/ab-test-rails/full-dashboard.png)

This shows one feature `"ab-test"` with two versions simply named `"a"` and `"b"`.

There are two goals called `"yes"` and `"no"`.

Version `"a"` is seen by 75% of the user-base, whether they are anonymous or not, and version `"b"` is seen by the remaining 25%.

You can read more about this example in a blog post here...
http://www.bigfastblog.com/ab-testing-in-ruby-on-rails


Rollout new versions of features
--------------------------------

Using `if ff? "foo"` you can easily rollout new code to production and then use the FluidFeatures dashboard to rollout this code to yourself, your team or your users.

Use `if ff? "foo", "v2"` to wrap the code for a new version of the "foo" feature.

`if ff? "foo"` defaults to version `"default"`, so anyone seeing "v2" will not also see "default". This is a great way to test new features in production.

Once you have moved all your users over to the newer "v2" version you can factor out code from the older version.

Tracking goals
--------------

Sometimes referred to as "conversions", goals are a simple way of flagging that an condition has been met. You can do this in your Rails controllers with `fluidgoal(<goal-name>)`. A statement such as `fluidgoal "upgraded-to-pro-account"` tells FluidFeatures that your user upgraded their account.

You can do this in controller, or in your view and you will immediately be able to see statistics within the FluidFeatures dashboard. Statistics show you will versions of which features play the greatest roll in driving your users towards these goals.

A/B testing
-----------

By combining 2 versions of a feature and one goal (see above) you can start to easily perform A/B testing. FluidFeatures will keep track of which version is winning in terms of statistically hitting the goal more often.

If you only roll out one of the versions to a small percentage, say 2%, of your user base, then this is taken into account when calculating the version success statistics. This means you can easily trial experimental features or new versions of existing features.

Multi-variant testing and beyond
--------------------------------

While A/B testing might be enough for some, you have the power to do much more.

You can define any number of versions for a feature and track them all.

You can also compare the performance of different features against each other over time.

In your controllers
-------------------

A/B testing on the server gives you the ability to test things at all levels of your stack. Test alternate SQL statements, different versions of emails sent to users, or different backend 3rd party API services.

In your views
-------------

fluidfeatures-rails exposes `def ff?` (alias to `def fluidfeature`) and `def fluidgoal` to your views, so can also wrap versioned code there.

User definition and cohorts
---------------------------

In your `application_controller.rb` you will define a function called `def fluidfeatures_current_user` which can be called by `gem fluidfeatures-rails` to determine who the current user is.

This important for FluidFeatures to determine which feature versions to enable for the user, but is also the place where you can define any cohorts you wish to use for rolling out features.

```ruby
def fluidfeatures_current_user(verbose)
  if current_user
    if verbose
      {
        :id => @current_user[:id],
        :name => @current_user[:name],
        :uniques => {
          :twitter => @current_user[:twitter_id]
        },
        :cohorts => {
          # Example attributes for the user.
          # These can be any fields you wish to select users by.
          :company  => {
            # "display" is used to help you find it in the dashboard.
            # Highly recommended unless you work with ids.
            # This display name can change over time without consequence. 
            :display => @current_user[:company_name],
            # "id" should be unique this this cohort and must be static
            # over time.
            :id      => @current_user[:company_id]
          },
          # For this boolean cohort "true"|"false" is the "display"
          # and the "id"
          :admin    => @current_user[:admin]
        }
      }
    else
      {
        :id => @current_user.id
      }
    end
  else
    nil
  end
end
```

The above is an example of `fluidfeatures_current_user` that you might implement. The `verbose` is a boolean that indicates whether all details are required, or just the minimal identifying attributes (unique `:id`). `verbose` is an optimization that will be used at the discretion of `gem fluidfeatures-rails`.

`:name` allows you to pass the human-readable string, such as `"John Doe"`, that represents the user. This is then used in the FluidFeatures dashboard for display and search purposes. You can very quickly search for this user and enable a new feature for them.

`:uniques` are other unique attributes of the user that you can pass to FluidFeatures. For instance, their Twitter handle. These can also be used for search in the dashboard. FluidFeatures may use these for further integrate, such as displaying Twitter profile pictures.

`:cohorts` are non-unique attributes of the user. You can define any attribute you wish. Common ones are `:admin` (`true` or `false`), but could be anything from the month when they joined (`:joined => "2011-04"`), to whether or not they drink coffee (`"coffee-drinker" => false`). Again, you can search on these attributes and enable specific versions of features based on these attributes.

Anonymous users
---------------

If your `ApplicationController` method `fluidfeatures_current_user` returns `nil` fluidfeatures-rails assumes that your user is anonymous and it will set a cookie in the user's browser. The cookie enables FluidFeatures to provide a consistent experience for that anonymous user. This is mostly important when you have feature versions enabled on a percentage of random users, when two anonymous user may have different features shown to them, depending on which percentage they random fall into.

It is possible handle anonymous users yourself by managing the cookies yourself, generating a unique `:id` for each anonymous user and additionally passing `:anonymous => true` in the `Hash` of `fluidfeatures_current_user` for both verbose and non-verbose calls. This basically what `gem fluidfeatures-rails` does under the hood for your convenience, so you do not have to.

