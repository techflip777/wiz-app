package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var Client *mongo.Client = CreateMongoClient()

func CreateMongoClient() *mongo.Client {
	err := godotenv.Load()
	if err != nil {
		log.Printf("Error loading .env file: %v", err)
	}

	MongoDbURI := os.Getenv("MONGODB_URI")
	if MongoDbURI == "" {
		log.Fatal("MONGODB_URI environment variable is not set")
	}

	client, err := mongo.NewClient(options.Client().ApplyURI(MongoDbURI))
	if err != nil {
		log.Fatal(err)
	}

	var ctx, cancel = context.WithTimeout(context.Background(), 10*time.Second)
	err = client.Connect(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer cancel()
	fmt.Println("Connected to MONGO -> ", MongoDbURI)
	return client
}

func OpenCollection(client *mongo.Client, collectionName string) *mongo.Collection {
	return client.Database("todoapp").Collection(collectionName)
}
