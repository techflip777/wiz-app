# Building the binary of the App
FROM golang:1.19 AS build

WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/wiz-app

FROM alpine:3.17.0 as release

WORKDIR /app
COPY --from=build /app/wiz-app .
COPY --from=build /app/assets ./assets
COPY wizexercise.txt .
EXPOSE 8081
ENTRYPOINT ["/app/wiz-app"]


