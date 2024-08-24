# Get the Roc compiler image
FROM docker.io/debian:bookworm AS roc-downloader

RUN apt-get update --fix-missing \
  && apt-get upgrade --yes \
  && apt-get install --yes wget \
  && wget -q -O roc.tar.gz https://github.com/roc-lang/roc/releases/download/nightly/roc_nightly-linux_x86_64-latest.tar.gz \
  && mkdir /usr/lib/roc \
  && tar -xvz -f roc.tar.gz --directory /usr/lib/roc --strip-components=1

FROM ghcr.io/gleam-lang/gleam:v1.5.1-erlang AS builder

WORKDIR /project

# Download the project's dependencies
COPY ./gleam.toml /project/gleam.toml
COPY ./manifest.toml /project/manifest.toml
RUN gleam deps download

# Copy the source files
COPY ./src /project/src

# Build the project
RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.5.1-erlang

# Copy the Roc compiler
COPY --from=roc-downloader /usr/lib/roc /usr/lib/roc
# Add it to the PATH
ENV PATH="$PATH:/usr/lib/roc"

# Copy the built app
COPY --from=builder /project/build/erlang-shipment /app

# Copy the static files
COPY ./static /app/static

WORKDIR /app
EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
