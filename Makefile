all:
	for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
		docker build -t cyrusimapd/$$dist - < $$dist ; \
	done

pull:
	for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
		docker pull cyrusimapd/$$dist ; \
	done

run:
	for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
		docker run -t -i \
			-e "COMMIT=$(COMMIT)" \
			-e "DIFFERENTIAL=$(DIFFERENTIAL)" \
			-e "PHAB_CERT=$(PHAB_CERT)" \
			-e "PHAB_USER=$(PHAB_USER)" \
			--rm=true cyrusimapd/$$dist 2>&1 | tee $$dist.log; \
	done

push:
	for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
		docker push cyrusimapd/$$dist ; \
	done

list:
	@for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
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

really-clean:
	for dist in $$(find . -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort | grep -E '^[a-z]+$$'); do \
		docker rmi cyrusimapd/$$dist ; \
		docker rmi $$dist ; \
	done

centos: rhel

debian: squeeze wheezy jessie sid

fedora: heisenbug twentyone rawhide

opensuse: bottle harlequin tumbleweed

rhel: santiago maipo

ubuntu: precise trusty utopic vivid

bottle:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

harlequin:
	docker build -t $@ - < $@
	docker run -it --entrypoint="/bin/bash" $@ -s

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

tumbleweed:
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

tikanga:
	docker build -t $@ - < tikanga.obsolete
	docker run -it --entrypoint="/bin/bash" $@ -s

.PHONY: bottle harlequin heisenbug jessie maipo precise rawhide santiago sid squeeze tikanga trusty tumbleweed twentyone utopic vivid wheezy
