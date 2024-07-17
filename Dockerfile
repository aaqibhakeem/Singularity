# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.75.0
ARG APP_NAME=singularity

################################################################################
# Create a stage for building the application.

FROM rust:${RUST_VERSION}-slim AS build
ARG APP_NAME
WORKDIR /app

# Install host build dependencies.
RUN apt-get update -y && \
  apt-get install -y pkg-config make g++ libssl-dev

# Create a non-privileged user that the app will run under.
RUN adduser --disabled-password --gecos "" --home "/nonexistent" --shell "/sbin/nologin" --no-create-home --uid 10001 appuser

# Copy the source code and build the application.
COPY . .
RUN cargo build --release

################################################################################
# Create a new stage for running the application that contains the minimal
# runtime dependencies for the application. This often uses a different base
# image from the build stage where the necessary files are copied from the build
# stage.
#
# The example below uses the distroless base image as the foundation for running the app.
# By specifying the "cc" tag, it will use the distroless image with the necessary runtime dependencies.
FROM gcr.io/distroless/cc AS final

# Copy the user information from the build stage.
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

# Copy the executable from the "build" stage.
COPY --from=build /app/target/release/${APP_NAME} /bin/${APP_NAME}
COPY singularity.yaml /app/
COPY src/assets/templates /app/src/assets/templates

# Switch to the non-privileged user.
USER appuser

# Expose the port that the application listens on.
EXPOSE 8080

# What the container should run when it is started.
CMD ["/bin/singularity"]

# ALT DOCKER FILE USING RUST-SLIM/ALPINE

# # syntax=docker/dockerfile:1

# ARG RUST_VERSION=1.75.0
# ARG APP_NAME=singularity

# ################################################################################
# # Create a stage for building the application.

# FROM rust:${RUST_VERSION}-alpine AS build
# ARG APP_NAME
# WORKDIR /app

# # Install host build dependencies.
# RUN apk add --no-cache clang lld musl-dev git openssl-dev

# # Build the application.
# # Leverage a cache mount to /usr/local/cargo/registry/
# # for downloaded dependencies, a cache mount to /usr/local/cargo/git/db
# # for git repository dependencies, and a cache mount to /app/target/ for
# # compiled dependencies which will speed up subsequent builds.
# # Leverage a bind mount to the src directory to avoid having to copy the
# # source code into the container. Once built, copy the executable to an
# # output directory before the cache mounted /app/target is unmounted.
# RUN --mount=type=bind,source=src,target=src \
#     --mount=type=bind,source=Cargo.toml,target=Cargo.toml \
#     --mount=type=bind,source=Cargo.lock,target=Cargo.lock \
#     --mount=type=cache,target=/app/target/ \
#     --mount=type=cache,target=/usr/local/cargo/git/db \
#     --mount=type=cache,target=/usr/local/cargo/registry/ \
# cargo build --locked --release && \
# cp ./target/release/$APP_NAME /bin/server

# ################################################################################
# # Create a new stage for running the application that contains the minimal
# # runtime dependencies for the application. This often uses a different base
# # image from the build stage where the necessary files are copied from the build
# # stage.
# #
# # The example below uses the alpine image as the foundation for running the app.
# # By specifying the "3.18" tag, it will use version 3.18 of alpine. If
# # reproducability is important, consider using a digest
# # (e.g., alpine@sha256:664888ac9cfd28068e062c991ebcff4b4c7307dc8dd4df9e728bedde5c449d91).
# FROM alpine:3.18 AS final

# # Create a non-privileged user that the app will run under.
# # See https://docs.docker.com/go/dockerfile-user-best-practices/
# ARG UID=10001
# RUN adduser \
#     --disabled-password \
#     --gecos "" \
#     --home "/nonexistent" \
#     --shell "/sbin/nologin" \
#     --no-create-home \
#     --uid "${UID}" \
#     appuser
# USER appuser

# # Copy the executable from the "build" stage.
# COPY --from=build /bin/server /bin/
# COPY singularity.yaml /app/
# COPY src/assets/templates /app/src/assets/templates

# # Expose the port that the application listens on.
# EXPOSE 8080

# # What the container should run when it is started.
# CMD ["/bin/server"]