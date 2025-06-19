# wiz-app
=======
# Docker
A Dockerfile has been provided to run this application.  The default port exposed is 8080.

# Environment Variables
The following environment variables are needed.
|Variable|Purpose|example|
|---|---|---|
|`MONGODB_URI`|Address to mongo server|`mongodb://servername:27017` or `mongodb://username:password@hostname:port` or `mongodb+srv://` schema|
|`SECRET_KEY`|Secret key for JWT tokens|`secret123`|

Alternatively, you can create a `.env` file and load it up with the environment variables.

# Running with Go

Clone the repository into a directory of your choice Run the command `go mod tidy` to download the necessary packages.

You'll need to add a .env file and add a MongoDB connection string with the name `MONGODB_URI` to access your collection for task and user storage.
You'll also need to add `SECRET_KEY` to the .env file for JWT Authentication.

Run the command `go run main.go` and the project should run on `locahost:8080`

# Nuances to the deployment - may be possible improvements :)
- Solution's infrastructure can be terraformed
  - Here are the steps (From the VSCode command line)
    - AZ login to the azure instance and choose the default subscription when given an option 
      - az account show
      - az ad sp create-for-rbac --name "wiz-exercise-sp" --role contributor --scopes /subscriptions/$(az account show --query id -o tsv) --sdk-auth
      - Copy the output to the GitHub secret (AZURE_CREDENTIALS) which will be used by deployment action script, for AZ login
    - Terraform Init -> Terraform Plan -> Terraform Apply
      - Note the mongodb ip address from the result
      - you might get an error stating that the ACR registry is not unique if you have a prior instance 
    - MongoDB installation
      - replace the IP in the below commands with the mongodb ip that you retrieved above and execute the same.
        - ssh azureuser@172.172.99.212 "sudo apt-get update -y && sudo apt-get install -y gnupg curl && curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor && echo \"deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse\" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list && sudo apt-get update -y && sudo apt-get install -y mongodb-org && sudo systemctl enable mongod && sudo systemctl start mongod && sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf && sudo systemctl restart mongod"
        - ssh azureuser@172.172.99.212 "mongosh 'mongodb://localhost:27017/todoapp' --eval 'db.createCollection(\"todos\")'"
        - ssh azureuser@172.172.99.212 "mongosh 'mongodb://localhost:27017/admin' --eval 'db.createUser({ user: \"azureuser\", pwd: \"Azure_123456\", roles: [{ role: \"readWrite\", db: \"todoapp\" }] })'"
    - Create another github secret (MONGODB_CONNECTION_STRING) and place the below connection string (after updating the ip address you retrieved from Azure Portal - NEED THE PRIVATE IP and not the ABOVE IP)
      - mongodb://azureuser:Azure_123456@10.0.1.4:27017/todoapp?authSource=admin
    - Manually run the `Test Azure Credentials` workflow to confirm if GitHub Actions is able to execute without flaw - this validates the azure credentials stored
    - Manually run the `Deploy to Azure` workflow, this will build the application and deploy to the Azure Container Registry (ACR)
      - The Workflow should run without trouble now
    - Retrieve the public ip of the cluster and try use the application

<img width="1177" alt="image" src="https://github.com/user-attachments/assets/ac75984f-b03f-4496-a885-cbffeacf8a1e" />


# License

This project is licensed under the terms of the MIT license.

Original project: https://github.com/dogukanozdemir/golang-todo-mongodb
# Trigger test
