FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=https://example.com
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine AS runtime
WORKDIR /usr/share/nginx/html

COPY docker/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web ./
COPY --from=build /app/web/flutter_service_worker.js ./flutter_service_worker.js

EXPOSE 80
