# Use fixed foundry image

FROM ghcr.io/foundry-rs/foundry:nightly-4a8c7d0e26a1befa526222e22737740f80a7f1c5

# Copy our source code into the container
WORKDIR /app
COPY . .

# Build the source code
EXPOSE 8545
RUN forge build
