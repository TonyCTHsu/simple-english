FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless && rm -rf /var/lib/apt/lists/*
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin se \
    && chown se:se /opt
COPY lib /src/lib
COPY rules /src/rules
COPY bin/se /src/bin/
COPY simple_english.gemspec /src/
COPY LICENSE README.md /src/
COPY docs/RULES.md /src/docs/
WORKDIR /src
RUN gem build simple_english.gemspec && gem install --no-document simple_english-*.gem
ENV SE_CACHE_DIR=/opt
USER 1000
RUN se setup --dir /opt
EXPOSE 8181
WORKDIR /work
ENTRYPOINT ["se"]
