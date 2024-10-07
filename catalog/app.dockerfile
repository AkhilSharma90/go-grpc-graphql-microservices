FROM golang:1.13-alpine3.11 AS build
RUN apk --no-cache add gcc g++ make ca-certificates
WORKDIR /go/src/github.com/akhilsharma90/go-graphql-microservice
COPY go.mod go.sum ./
COPY vendor vendor
COPY catalog catalog
RUN GO111MODULE=on go build -mod vendor -o /go/bin/app ./catalog/cmd/catalog

FROM alpine:3.11
WORKDIR /usr/bin
COPY --from=build /go/bin .
EXPOSE 8080
CMD ["app"]
