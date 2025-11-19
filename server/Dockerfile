FROM google/dart:2.19

WORKDIR /app
COPY . .

# Install dependencies
RUN dart pub get

# Build the server
RUN dart compile exe bin/server.dart -o bin/server

EXPOSE 3000
CMD ["./bin/server"]