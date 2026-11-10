FROM instructure/ruby-passenger:3.4-jammy

ENV APP_HOME="/usr/src/app/"

USER root

RUN echo "deb https://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
   && curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
   && apt-get update && apt-get install -y \
   postgresql-client-17 \
   libpq-dev \
   git \
   tzdata \
   && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock* $APP_HOME
RUN chown -R docker:docker $APP_HOME

USER docker
RUN bundle install --quiet --jobs 8
USER root

COPY . $APP_HOME
RUN mkdir -p log tmp && chown -R docker:docker $APP_HOME

USER docker

EXPOSE 80
CMD ["bash", "-lc", "rm -f tmp/pids/server.pid && bundle exec rails server -b 0.0.0.0 -p 80"]
