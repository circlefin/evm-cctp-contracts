# Use fixed foundry image
ARG FOUNDRY_VERSION=nightly-4a8c7d0e26a1befa526222e22737740f80a7f1c5

FROM ghcr.io/foundry-rs/foundry:${FOUNDRY_VERSION}

# Copy our source code into the container
WORKDIR /app
COPY . .

# Build the source code
EXPOSE 8545
RUN forge build
