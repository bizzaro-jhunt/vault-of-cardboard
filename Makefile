test:
	prove -lv t/*.t

coverage:
	rm -rf cover_db
	cover -t -ignore_re '^t/.*' -ignore_re '/VCB/Test\.pm$$'

build:
	docker build . -t huntprod/vault-of-cardboard

push: build
	docker push huntprod/vault-of-cardboard

PORT ?= 8001
local:
	docker volume inspect vcb-cache  >/dev/null 2>&1 || docker volume create vcb-cache
	docker volume inspect vcb-dat    >/dev/null 2>&1 || docker volume create vcb-dat
	docker volume inspect vcb-db     >/dev/null 2>&1 || docker volume create vcb-db
	docker run -it -p $(PORT):80 \
	           -v vcb-cache:/app/cache \
	           -v vcb-dat:/app/dat \
	           -v vcb-db:/data \
	           -e SCRY_DEBUG=yes \
	           huntprod/vault-of-cardboard

local-env:
	@echo "export VCB_API=http://127.0.0.1:$(PORT);"
	@echo "export VCB_USERNAME=urza;"
	@echo "export VCB_PASSWORD=admin;"
	@echo 'echo "connected to $$VCB_API as $$VCB_USERNAME"'
