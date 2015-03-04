all:
	for dist in precise santiago trusty utopic vivid; do \
		docker build -t cyrusimapd/$$dist - < $$dist ; \
	done
