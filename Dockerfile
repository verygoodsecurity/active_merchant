FROM ruby:2.7-alpine

RUN apk update && apk add --no-cache build-base libxml2-dev curl

WORKDIR /active_merchant
ADD lib lib
ADD test test
ADD Gemfile .
ADD Gemfile.lock .
ADD activemerchant.gemspec .
ADD deploy.sh .
ADD Rakefile .

RUN gem install bundler -v 2.2.21
# RUN gem update --system            \
#     && gem install bundler
RUN bundle install

ADD lib lib