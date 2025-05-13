FROM golang:1.20-alpine AS build
RUN apk --no-cache add gcc g++ make ca-certificates
WORKDIR /go/src/github.com/akhilsharma90/go-graphql-microservice
COPY go.mod go.sum ./
COPY vendor vendor
COPY account account
COPY catalog catalog
COPY order order
COPY graphql graphql
RUN GO111MODULE=on go build -mod vendor -o /go/bin/app ./graphql

FROM alpine:3.11
WORKDIR /usr/bin
ENV ACCOUNT_SERVICE_URL=my-account-service \
    CATALOG_SERVICE_URL=my-catalog-service \
    ORDER_SERVICE_URL=my-order-service
COPY --from=build /go/bin .
EXPOSE 8080
CMD ["app"]
