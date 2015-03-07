all:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker build -t cyrusimapd/$$dist --no-cache=true - < $$dist ; \
	done

pull:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker pull cyrusimapd/$$dist ; \
	done

run:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker run -t -i \
			-e "PHAB_CERT=$(PHAB_CERT)" \
			-e "DIFFERENTIAL=$(DIFFERENTIAL)" \
			--rm=true cyrusimapd/$$dist 2>&1 | tee $$dist.log; \
	done

push:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker push cyrusimapd/$$dist ; \
	done

list:
	@for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		echo $$dist ; \
	done

clean:
	for container in $$(docker ps -q); do \
		docker kill --signal="SIGKILL" $$container ; \
	done
	for container in $$(docker ps -aq); do \
		docker rm -f $$container ; \
	done
	for image in $$(docker images -aq --filter dangling=true); do \
		docker rmi -f $$image ; \
	done

heisenbug:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

jessie:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

maipo:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

precise:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

rawhide:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

santiago:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

sid:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

squeeze:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

trusty:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

twentyone:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

utopic:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

vivid:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

wheezy:
	docker build -t cyrusimapd/$@ - < $@
	docker run -it --entrypoint="/bin/bash" cyrusimapd/$@ -s

.PHONY: heisenbug maipo precise rawhide santiago sid squeeze trusty twentyone utopic vivid wheezy
