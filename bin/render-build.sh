# !/usr/bin/env bash
set -o errexit

docker compose down
docker compose run --rm web rails db:drop

docker compose up
bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate
