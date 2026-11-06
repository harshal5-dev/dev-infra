# 🛠️ `dev-infra` — Shared Local Platform

Central infrastructure repository managing shared platform dependencies (**RabbitMQ**, **Kafka**, **PostgreSQL**, **Redis**, and **Ingress**) on a local `k3d` Kubernetes cluster.

Any independent microservice or application project can connect to these shared services without running its own duplicate databases or message brokers.

---

## 📂 Repository Structure

```text
dev-infra/
├── README.md                        # This documentation & connection cheat-sheet
├── Makefile                         # 1-command startup & teardown
├── k3d-config.yaml                  # k3d cluster specification & port bindings
│
├── base/                            # Shared namespaces & RBAC
│   └── namespaces.yaml              # messaging, database, shared namespaces
│
├── messaging/                       # Shared message brokers & event streaming
│   ├── rabbitmq/
│   │   ├── secret.yaml.example      # Template for admin credentials (committed)
│   │   ├── secret.yaml              # Local admin credentials (gitignored)
│   │   ├── pvc.yaml                 # Persistent data volume
│   │   └── rabbitmq.yaml            # Deployment & ClusterIP Service (RabbitMQ 4)
│   └── kafka/
│       ├── configmap.yaml           # Cluster ID & KRaft properties
│       ├── pvc.yaml                 # Persistent partition logs
│       └── kafka.yaml               # Kafka KRaft single-node deployment
│
├── databases/                       # Shared datastores
│   ├── postgres/
│   │   ├── secret.yaml.example      # Template for superuser credentials (committed)
│   │   ├── secret.yaml              # Local superuser credentials (gitignored)
│   │   ├── pvc.yaml                 # Database storage
│   │   └── postgres.yaml            # PostgreSQL 16 Deployment & Service
│   └── redis/
│       └── redis.yaml               # Redis cache Deployment & Service
│
└── networking/                      # Ingress & DNS routes
    └── local-ingress.yaml           # Traefik routes for Web UIs
```

---

## 🚀 Quick Start

### 1. Prerequisite Tools
Ensure the following are installed on your Mac:
* [Docker Desktop](https://www.docker.com/) (or OrbStack)
* [k3d](https://k3d.io/): `brew install k3d`
* [kubectl](https://kubernetes.io/docs/tasks/tools/): `brew install kubectl`

### 2. Configure Local Secrets
Secret manifests (`secret.yaml`) are ignored by Git so credentials are never committed. Copy the example secret file and set your local username and password:

```bash
cp messaging/rabbitmq/secret.yaml.example messaging/rabbitmq/secret.yaml
```

### 3. Start Everything in 1 Command
From the root of this `dev-infra` repository, run:

```bash
# Starts the cluster and applies all infrastructure manifests
make up
```

### 4. Check Service Status
```bash
make status
```

---

## 📋 Service Catalog & Connection Cheat Sheet

| Service | Protocol | Inside K8s (Cluster DNS) | From Host Mac (Localhost) | Credentials |
| :--- | :--- | :--- | :--- | :--- |
| **RabbitMQ (AMQP)** | AMQP | `rabbitmq.messaging.svc.cluster.local:5672` | `localhost:5672` | *(Set in `messaging/rabbitmq/secret.yaml`)* |
| **RabbitMQ (Web UI)** | HTTP | `rabbitmq.messaging.svc.cluster.local:15672` | `http://localhost:15672` | *(Set in `messaging/rabbitmq/secret.yaml`)* |
| **Kafka (KRaft)** | TCP | `kafka.messaging.svc.cluster.local:9092` | `localhost:9092` | *(None / Plaintext)* |
| **PostgreSQL** | SQL | `postgres.database.svc.cluster.local:5432` | `localhost:5432` | *(Set in `databases/postgres/secret.yaml`)* |
| **Redis** | Redis | `redis.database.svc.cluster.local:6379` | `localhost:6379` | *(None by default)* |

---

## 🔌 How to Use in Other Projects

When building an independent project (e.g. `project-ecommerce`, `fintech-api`, `chat-service`), connect to `dev-infra` based on where your app is running:

### Mode A: Running Your App Locally on Mac (`go run`, `npm start`, tests)
Configure your application’s `.env` or configuration file to point to `localhost`:

```bash
# In your project's .env file:
RABBITMQ_URL="amqp://<RABBITMQ_USER>:<RABBITMQ_PASS>@localhost:5672/"
KAFKA_BROKERS="localhost:9092"
DATABASE_URL="postgres://<POSTGRES_USER>:<POSTGRES_PASS>@localhost:5432/my_project_db?sslmode=disable"
REDIS_URL="localhost:6379"
```

---

### Mode B: Deploying Your App into the Kubernetes Cluster
When your microservice runs as a pod inside `k3d`, use Kubernetes internal DNS:

```yaml
# In your microservice deployment.yaml
env:
  - name: RABBITMQ_URL
    value: "amqp://<RABBITMQ_USER>:<RABBITMQ_PASS>@rabbitmq.messaging.svc.cluster.local:5672/"
  - name: KAFKA_BROKERS
    value: "kafka.messaging.svc.cluster.local:9092"
  - name: DATABASE_URL
    value: "postgres://<POSTGRES_USER>:<POSTGRES_PASS>@postgres.database.svc.cluster.local:5432/my_project_db?sslmode=disable"
  - name: REDIS_URL
    value: "redis.database.svc.cluster.local:6379"
```

---

## 🏢 Multi-Tenancy: Sharing Resources Across Projects

To avoid collisions when multiple projects use the same shared infrastructure:

### 1. RabbitMQ Virtual Hosts (`vhost`)
Do not mix queues in the default `/` vhost. Create an isolated vhost for each project:
* E-Commerce Project: `amqp://<RABBITMQ_USER>:<RABBITMQ_PASS>@rabbitmq.../ecommerce`
* Notification Project: `amqp://<RABBITMQ_USER>:<RABBITMQ_PASS>@rabbitmq.../notifications`

### 2. Kafka Topic Naming Convention
Prefix all Kafka topic names with the project and environment name:
* `<project>.<domain>.<event>`
* Example: `fintech.payments.processed`
* Example: `ecommerce.orders.created`

### 3. PostgreSQL Databases
Do not use the default `postgres` database. Create a separate database per project within the shared instance:
```sql
CREATE DATABASE ecommerce_db;
CREATE DATABASE fintech_db;
```

---

## 🧰 Management Commands (`Makefile`)

```makefile
.PHONY: up down stop start status

up:
	k3d cluster create --config k3d-config.yaml
	kubectl apply -f base/
	kubectl apply -f messaging/rabbitmq/

down:
	k3d cluster delete platform-dev

stop:
	k3d cluster stop platform-dev

start:
	k3d cluster start platform-dev

status:
	kubectl get pods -A
```
