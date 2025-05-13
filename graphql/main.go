//go:generate go run github.com/99designs/gqlgen
package main

import (
	"log"
	"net/http"
	"github.com/99designs/gqlgen/handler"
	"github.com/kelseyhightower/envconfig"
)

type AppConfig struct {
	AccountURL string `envconfig:"ACCOUNT_SERVICE_URL"`
	CatalogURL string `envconfig:"CATALOG_SERVICE_URL"`
	OrderURL   string `envconfig:"ORDER_SERVICE_URL"`
}

func main() {
	var cfg AppConfig
	err := envconfig.Process("", &cfg)
	if err != nil {
		log.Fatal(err)
	}

	s, err := NewGraphQLServer(cfg.AccountURL, cfg.CatalogURL, cfg.OrderURL)
	if err != nil {
		log.Fatal(err)
	}

	http.Handle("/graphql", handler.GraphQL(s.ToExecutableSchema()))

	http.HandleFunc("/playground", func(w http.ResponseWriter, r *http.Request) {
		log.Println("graphql got hit!!!!")
		handler.Playground("akhil", "/graphql").ServeHTTP(w, r)
	})

	log.Printf("GraphQL server v3 is running on port 8080 and using AccountURL: %s, CatalogURL: %s, OrderURL: %s", cfg.AccountURL, cfg.CatalogURL, cfg.OrderURL)

	log.Fatal(http.ListenAndServe(":8080", nil))
}


