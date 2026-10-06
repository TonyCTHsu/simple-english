FROM ruby:3.3-slim
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin se
ARG VERSION
RUN gem install --no-document simple_english -v "${VERSION}"
USER 1000
WORKDIR /work
ENTRYPOINT ["se"]
