all:
	for dist in precise santiago trusty utopic vivid; do \
		docker build -t cyrusimapd/$$dist - < $$dist ; \
	done

run:
	for dist in precise santiago trusty utopic vivid; do \
		docker run -t -i --rm=true cyrusimapd/$$dist ; \
	done
