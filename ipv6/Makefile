SRCS=ip_socket.c udpserver.c udpclient.c
LIBS=ip_socket.o
#EXECUTABLES=udpserver udpclient addrinfo
EXECUTABLES=udpserver udpclient

CC=gcc
CFLAGS=-g -Wall
LDFLAGS=

OBJS=$(SRCS:.c=.o)

all: $(EXECUTABLES)

$(EXECUTABLES): $(OBJS)
	$(CC) $(CFLAGS) $@.o $(LIBS) $(LDFLAGS) -o $@  

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

#addrinfo: addrinfo.c
#	$(CC) $(CFLAGS) -o addrinfo addrinfo.c


clean:
	rm -rf $(EXECUTABLES) $(OBJS)
