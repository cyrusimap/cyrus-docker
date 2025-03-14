dar: ../bin/dar
	fatpack packlists-for IPC/Run.pm Path/Tiny.pm Process/Status.pm > packlists
	fatpack tree `cat packlists`
	fatpack file ../bin/dar > dar
	chmod u+x dar

clean:
	rm -f dar
	rm -f packlists
	rm -f fatpacker.trace
