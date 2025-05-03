SERVICE_NAME := gallformers

# Check for required .env.local file
env-check:
ifeq (,$(wildcard .env.local))
	$(error You must have an .env.local file containing secrets!)
endif

# Environment setup functions
define setup-env
	cp $(1) .env
	cat .env.local >> .env
	# Create prisma/.env with the appropriate DATABASE_URL from .env
	mkdir -p prisma
	cp .env prisma/.env
endef

define cleanup-env
	rm -f .env
	rm -f prisma/.env
endef

# Development environment - runs directly with yarn
.PHONY: dev
dev: env-check
ifeq (,$(wildcard .env.development))
	$(error You must have an .env.development file!)
endif
	$(call setup-env,.env.development)
	yarn dev
	$(call cleanup-env)

# Production environment - AMD64 Docker build
.PHONY: prod-build
prod-build: env-check
ifeq (,$(wildcard .env.production))
	$(error You must have an .env.production file!)
endif
	$(call setup-env,.env.production)
	BUILD_PLATFORM=linux/amd64 docker buildx bake -f docker-compose.yml --load
	$(call cleanup-env)

.PHONY: prod-run
prod-run: env-check
	$(call setup-env,.env.production)
	docker stop $(SERVICE_NAME) || true
	docker rm $(SERVICE_NAME) || true
	docker run --restart=always \
		-v ${PWD}/prisma:/usr/src/app/prisma \
		-v ${PWD}/ref:/usr/src/app/ref \
		--env-file .env \
		--name $(SERVICE_NAME) \
		-p 3000:3000 \
		-d $(SERVICE_NAME):latest
	docker start $(SERVICE_NAME)
	$(call cleanup-env)

.PHONY: prod
prod: prod-build prod-run

# Local Docker environment - ARM64 Docker build
.PHONY: local-docker-build
local-docker-build: env-check
ifeq (,$(wildcard .env.local-docker))
	$(error You must have an .env.local-docker file!)
endif
	$(call setup-env,.env.local-docker)
	BUILD_PLATFORM=linux/arm64 docker buildx bake -f docker-compose.yml --load
	$(call cleanup-env)

.PHONY: local-docker-run
local-docker-run: env-check
	$(call setup-env,.env.local-docker)
	docker stop $(SERVICE_NAME) || true
	docker rm $(SERVICE_NAME) || true
	docker run \
		-v ${PWD}/prisma:/usr/src/app/prisma \
		-v ${PWD}/ref:/usr/src/app/ref \
		--env-file .env \
		--name $(SERVICE_NAME) \
		-p 3000:3000 \
		-d $(SERVICE_NAME):latest
	docker start $(SERVICE_NAME)
	$(call cleanup-env)

.PHONY: local-docker
local-docker: local-docker-build local-docker-run

# Utility commands
.PHONY: stop
stop:
	docker stop $(SERVICE_NAME) || true
	docker rm $(SERVICE_NAME) || true

.PHONY: clean
clean: stop
	docker rmi $(SERVICE_NAME):latest || true
	$(call cleanup-env)

.PHONY: logs
logs:
	docker logs -f $(SERVICE_NAME)

.PHONY: restart-prod
restart-prod: stop prod-run

.PHONY: restart-local-docker
restart-local-docker: stop local-docker-run

# Server deployment commands
.PHONY: save-image
save-image:
	docker save $(SERVICE_NAME):latest > $(SERVICE_NAME)-docker.tar

.PHONY: load-image
load-image: stop
	docker load < $(SERVICE_NAME)-docker.tar

.PHONY: server-run
server-run: env-check
ifeq (,$(wildcard .env.production))
	$(error You must have an .env.production file!)
endif
	$(call setup-env,.env.production)
	docker stop $(SERVICE_NAME) || true
	docker rm $(SERVICE_NAME) || true
	docker run --restart=always \
		-v /mnt/gallformers_data/prisma:/usr/src/app/prisma \
		-v ${PWD}/ref:/usr/src/app/ref \
		--env-file .env \
		--name $(SERVICE_NAME) \
		-p 3000:3000 \
		-d $(SERVICE_NAME):latest
	docker start $(SERVICE_NAME)
	$(call cleanup-env)

.PHONY: server-restart
server-restart: stop server-run

.PHONY: redeploy-and-run
redeploy-and-run: load-image server-run

# Server deployment with maintenance mode
.PHONY: server-deploy
server-deploy:
	@if [ ! -f $(SERVICE_NAME)-docker.tar ]; then \
		echo "Error: $(SERVICE_NAME)-docker.tar not found in project root"; \
		exit 1; \
	fi
	@if [ "$$(id -u)" != "0" ]; then \
		echo "Error: This command must be run as root (sudo)"; \
		exit 1; \
	fi
	@echo "Putting server into maintenance mode..."
	cp maintenance.html /var/www/html
	@echo "Running redeploy-and-run..."
	make redeploy-and-run
	@echo "Checking if container is running..."
	@if ! docker ps | grep -q $(SERVICE_NAME); then \
		echo "Error: Container $(SERVICE_NAME) is not running after deployment"; \
		exit 1; \
	fi
	@echo "Removing maintenance mode..."
	rm /var/www/html/maintenance.html
	@echo "Deployment completed successfully!"

# Database management
.PHONY: update-database
update-database:
	cp -r prisma /mnt/gallformers_data

# Server bootstrap commands
.PHONY: bootstrap
bootstrap:
	apt-get install haveged
	update-rc.d haveged defaults

	ufw allow 80
	ufw allow 443
	ufw enable

	apt-get install nginx-full
	ln -s nginx/nginx.conf /etc/nginx/conf.d/nginx.conf

	install core
	snap refresh core

	snap install --classic certbot
	ln -s /snap/bin/certbot /usr/bin/certbot	
	
	# gets the certs and installs them changing the nginx configuration
	certbot --nginx
	