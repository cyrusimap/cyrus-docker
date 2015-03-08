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
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

jessie:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

maipo:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

precise:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

rawhide:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

santiago:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

sid:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

squeeze:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

trusty:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

twentyone:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

utopic:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

vivid:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

wheezy:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

.PHONY: heisenbug jessie maipo precise rawhide santiago sid squeeze trusty twentyone utopic vivid wheezy
