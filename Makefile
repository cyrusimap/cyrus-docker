all:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker build -t cyrusimapd/$$dist - < $$dist ; \
	done

pull:
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker pull cyrusimapd/$$dist ; \
	done

run: pull
	for dist in $$(ls -1 | grep -E '^[a-z]+$$'); do \
		docker run -t -i --rm=true cyrusimapd/$$dist ; \
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

