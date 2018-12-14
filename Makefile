build:
	docker build . -t huntprod/vault-of-cardboard

push: build
	docker push huntprod/vault-of-cardboard
