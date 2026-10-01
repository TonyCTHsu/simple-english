FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless && rm -rf /var/lib/apt/lists/*
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin se \
    && chown se:se /opt
ARG VERSION
RUN gem install --no-document simple_english -v "${VERSION}"
ENV SE_CACHE_DIR=/opt
USER 1000
RUN se setup
EXPOSE 8181
WORKDIR /work
ENTRYPOINT ["se"]
