#ifndef _IP_SOCKET
#define _IP_SOCKET

#include <arpa/inet.h>
#include <sys/socket.h>

/* Socket address structure here are generic so that they
   can support either 
   ipv4 - struct sockaddr_in, or
   ipv6 - struct sockaddr_in6

*/

typedef struct ip_obj {
  int sockfd;			/* socket file descriptor */
  struct sockaddr_in6 from;	/* address sending to socket */
  struct sockaddr_in6 dest;	/* socket address for destination */
} ip_obj_t;

#endif

ip_obj_t *sock_udp_client(char *dest, char *port);
ssize_t sock_sendto(ip_obj_t *sock, char *buf, size_t len);
ssize_t sock_recvfrom(ip_obj_t *sock, char *buf, size_t len);

ip_obj_t *sock_udp_server(int port);
ssize_t sock_sendbackto(ip_obj_t *sock, char *buf, size_t len);

char *sock_getaddr(ip_obj_t *sock);
char *sock_getaddr_dest(ip_obj_t *sock);

