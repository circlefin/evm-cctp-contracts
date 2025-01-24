ARG FOUNDRY_VERSION=nightly-3fa02706ca732c994715ba42d923605692062375
# Use fixed foundry image
FROM ghcr.io/foundry-rs/foundry:${FOUNDRY_VERSION}

# Copy our source code into the container
WORKDIR /app
COPY . .

# Build the source code
EXPOSE 8545
RUN forge build
