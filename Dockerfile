# Use the latest foundry image

FROM ghcr.io/foundry-rs/foundry

# Copy our source code into the container
WORKDIR /app
COPY . .

# Build the source code
EXPOSE 8545
RUN forge build
