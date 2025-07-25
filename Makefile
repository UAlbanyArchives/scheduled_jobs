build:
	docker build -t jobs .

# Build production image with no cache
build-nocache:
	docker build --no-cache -t jobs .
