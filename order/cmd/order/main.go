package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/akhilsharma90/go-graphql-microservice/order"
	"github.com/kelseyhightower/envconfig"
	"github.com/tinrab/retry"
	_ "github.com/lib/pq"
)


type Config struct {
	DatabaseURL string `envconfig:"DATABASE_URL_ORDER"`
	AccountURL  string `envconfig:"ACCOUNT_SERVICE_URL"`
	CatalogURL  string `envconfig:"CATALOG_SERVICE_URL"`
	ENV         string `envconfig:"ENV"`
}

func getConnectionString(cfg Config) (string, error) {
	switch cfg.ENV {
	case "prod":
		return fmt.Sprintf("postgres://postgres:postgres@%s:5432/postgres", cfg.DatabaseURL), nil
	case "dev":
		return cfg.DatabaseURL, nil
	default:
		return "", fmt.Errorf("invalid environment: %s", cfg.ENV)
	}
}

func initDb(cfg Config) {
	connStr, err := getConnectionString(cfg)
	if err != nil {
		log.Fatalf("Failed to determine connection string: %v", err)
	}

	log.Printf("Initializing the database for environment: %s...\n", cfg.ENV)
	var db *sql.DB

	retry.ForeverSleep(2*time.Second, func(_ int) error {
		db, err = sql.Open("postgres", connStr)
		if err != nil {
			log.Println("Retrying database connection:", err)
			return err
		}

		if pingErr := db.Ping(); pingErr != nil {
			log.Println("Retrying database ping:", pingErr)
			return pingErr
		}
		return nil
	})
	defer db.Close()


	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS orders (
			id CHAR(27) PRIMARY KEY,
			created_at TIMESTAMP WITH TIME ZONE NOT NULL,
			account_id CHAR(27) NOT NULL,
			total_price MONEY NOT NULL
		);
		CREATE TABLE IF NOT EXISTS order_products (
			order_id CHAR(27) REFERENCES orders(id) ON DELETE CASCADE,
			product_id CHAR(27),
			quantity INT NOT NULL,
			PRIMARY KEY (product_id, order_id)
		);
	`)
	if err != nil {
		log.Fatalf("Failed to execute database initialization script: %v", err)
	}

	log.Println("Database initialization complete.")
}

func startService(cfg Config) {
	connStr, err := getConnectionString(cfg)
	if err != nil {
		log.Fatalf("Failed to determine connection string: %v", err)
	}

	var r order.Repository

	retry.ForeverSleep(2*time.Second, func(_ int) error {
		r, err = order.NewPostgresRepository(connStr)
		if err != nil {
			log.Println("Retrying connection to repository:", err)
		}
		return err
	})
	defer r.Close()


	s := order.NewService(r)
	log.Println("Listening on port 8080 for gRPC...")
	log.Fatal(order.ListenGRPC(s, cfg.AccountURL, cfg.CatalogURL, 8080))
}

func main() {
	var cfg Config
	err := envconfig.Process("", &cfg)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	initDb(cfg)
	startService(cfg)
}
