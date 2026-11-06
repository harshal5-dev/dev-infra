
.PHONY: up down stop start status

up:
	k3d cluster create --config k3d-config.yaml
	kubectl apply -f base/
	kubectl apply -f messaging/rabbitmq/
# Uncomment the lines below as you add Kafka, PostgreSQL, and Redis in later phases:
# kubectl apply -f messaging/kafka/
# kubectl apply -f databases/postgres/
# kubectl apply -f databases/redis/

down:
	k3d cluster delete platform-dev

stop:
	k3d cluster stop platform-dev

start:
	k3d cluster start platform-dev

status:
	kubectl get pods -A
