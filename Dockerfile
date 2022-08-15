# Use the latest foundry image
FROM 124945441934.dkr.ecr.us-east-1.amazonaws.com/blockchain/ethereum/foundry

# Copy our source code into the container
WORKDIR /app
COPY . .

# Build the source code
EXPOSE 8545
RUN forge build
