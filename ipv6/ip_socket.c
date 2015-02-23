#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <sys/socket.h>
#include <netdb.h> 

#include "ip_socket.h"

/* translate address family into a string */
char *getAF(int af) {
  switch (af) {
  case AF_UNSPEC: return("AF_UNSPEC");
  case AF_UNIX:return("AF_UNIX");
  case AF_INET: return("AF_INET"); /* internetwork: UDP, TCP, etc. */
  case AF_INET6: return("AF_INET6");	       /* IPv6 */
  }
  return("af unknown");
}

/* Translae a socket type into a string */
char *getsocktype(int st) {
  switch (st) {
  case SOCK_STREAM: return("SOCK_STREAM"); /* stream socket */
  case SOCK_DGRAM: return("SOCK_DGRAM");   /* datagram socket */
  case SOCK_RAW: return("SOCK_RAW");	/* raw-protocol interface */
  case SOCK_RDM: return("SOCK_RDM"); /* reliably-delivered message */
  case SOCK_SEQPACKET: return("SOCK_SEQPACKET"); /* sequenced packet stream */
  }
  return("unknown");
}

/* translate a protocol into a string */
char *getprotocol(int p) {
  switch (p) {
  case IPPROTO_UDP: return("UDP"); 
  case IPPROTO_TCP: return("TCP"); 
  case 0: return("any");
  }
  return("unknown");
}


/* utility to clear the IPv6 only socket option, which used to be default */
int clearV6only(int sockfd) {
  int opt = 0;
  socklen_t optlen = sizeof(opt);

  /* make sure IPV6_V6 only option is not set */
  opt = 0;
  if (setsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, &opt, sizeof(opt))) {
    fprintf(stderr, "unable to set socket option\n");
    return -1;
  }
  /* verify that it is clear */
  if (getsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, &opt, &optlen)) {
    fprintf(stderr, "unable to get socket option\n");
    return -1;
  }

  printf("getsockopt IPV6_V6ONLY: %d (%d)\n", opt, optlen);
  if (opt) {
    fprintf(stderr, "unable to clear IPV6_V6ONLY option\n");
    return -1;
  }
  return 0;
}

/* 
   udp server handles all incoming datagrams as if they were ipv6.  
   ipv4 traffic appear as v4 in v6 using the IPv6 transition addressing
   ::ffff:xxx.xxx.xxx.xxx for ipv4 address xxx.xxx.xxx.xxx
 */

ip_obj_t *sock_udp_server(int port) {
  int sockfd = 0;
  struct in6_addr addrany = IN6ADDR_ANY_INIT;
  struct sockaddr_in6 server;

  /* create UDP/IPv6 socket that can handle v4 too */
  if ((sockfd = socket(AF_INET6, SOCK_DGRAM, 0)) < 0) return NULL;
  if (clearV6only(sockfd)) return NULL;

  /* create the socket object */
  ip_obj_t *udpsock = malloc(sizeof(ip_obj_t));
  udpsock->sockfd = sockfd;

  /* build the address structure to receive any ipv6 on port */
  server.sin6_family = AF_INET6;	/* ipv6 addressing */
  server.sin6_port = htons(port);
  memcpy(&server.sin6_addr, &addrany, sizeof(addrany));
  
  /* bind to the port, cast v6 address struct to generic socket add */
  if (bind(udpsock->sockfd, (struct sockaddr *) &server, sizeof(server))) {
    free(udpsock);
    udpsock = NULL;
  }
  return udpsock;
}

/* get a UDP sockaddr struct for destination, preferring v6 */
struct sockaddr *getIPv6(char *dest, char *port) {
  struct addrinfo *dests_addrinfo;
  struct addrinfo *dp;
  struct sockaddr *ipv4addr = NULL;

  if (getaddrinfo(dest, port, NULL, &dests_addrinfo)) {
    return NULL;    
  }
  for (dp=dests_addrinfo; dp; dp=dp->ai_next) {
    /* print out the addresses we find */
    printf("ai_family: (%d) %s ", dp->ai_family, 
	   getAF(dp->ai_family));
    printf("ai_socktype: (%d) %s ", dp->ai_socktype, 
	   getsocktype(dp->ai_socktype));
    printf("ai_protocol: (%d) %s\n", dp->ai_protocol, 
	   getprotocol(dp->ai_protocol));

    if ((dp->ai_family == AF_INET6) &&
	(dp->ai_protocol == IPPROTO_UDP)) return dp->ai_addr;
    if ((dp->ai_family == AF_INET) &&
	(dp->ai_protocol == IPPROTO_UDP)) 
      ipv4addr = dp->ai_addr;
  }
  return ipv4addr;		/* return UDP/ipv4 if have one */
}

ip_obj_t *sock_udp_client(char *dest, char *port) {
  int sockfd = 0;
  struct sockaddr *destaddr;
  
  printf("Create UDP socket for %s:%s\n", dest, port);

  /* create a socket object */
  ip_obj_t *udpsock = malloc(sizeof(ip_obj_t));
  memset(udpsock, 0, sizeof(ip_obj_t));

  /* get a sockaddr for the destination */
  destaddr = getIPv6(dest, port);
  if (!destaddr) {
    fprintf(stderr,"unable to get dest addr\n");
    free(udpsock);
    return NULL;    
  }

  /* create the corresponding socket */
  if (destaddr->sa_family == AF_INET6) {
    printf("creating ipv6 socket\n");
    sockfd = socket(AF_INET6, SOCK_DGRAM, 0);
    /* copy the sockaddr struct */
    memcpy(&udpsock->dest, destaddr, sizeof(struct sockaddr_in6));
    /* create UDP/IPv6 socket */
  } else if (destaddr->sa_family == AF_INET) {
    printf("creating ipv4 socket\n");
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    memcpy(&udpsock->dest, destaddr, sizeof(struct sockaddr_in));
  }

  if (!sockfd) {
    fprintf(stderr,"unable to allocate socket\n");
    free(udpsock);
    return NULL;
  }
  udpsock->sockfd = sockfd;
  //  if (clearV6only(sockfd)) return NULL;
  return udpsock;
}

/* create readable form of IPv4 or ipv6 from addr */

char *sock_getaddr(ip_obj_t *sock) {
  char *res = malloc(INET6_ADDRSTRLEN);
  struct sockaddr * sa = (struct sockaddr *) &sock->from;
  if (sa->sa_family == AF_INET6) {  
    struct sockaddr_in6 *from6 = (struct sockaddr_in6 *) &sock->from;
    inet_ntop(AF_INET6, &from6->sin6_addr, res, INET6_ADDRSTRLEN);
  } else if (sa->sa_family == AF_INET) {  
    struct sockaddr_in *from4 = (struct sockaddr_in *) &sock->from;
    inet_ntop(AF_INET, &from4->sin_addr, res, INET_ADDRSTRLEN);
  }
  return res;
}
char *sock_getaddr_dest(ip_obj_t *sock) {
  struct sockaddr * sa = (struct sockaddr *) &sock->dest;
  char *res = malloc(INET6_ADDRSTRLEN);
  if (sa->sa_family == AF_INET6) {  
    struct sockaddr_in6 *dest6 = (struct sockaddr_in6 *) &sock->dest;
    inet_ntop(AF_INET6, &dest6->sin6_addr, res, INET6_ADDRSTRLEN);
  } else if (sa->sa_family == AF_INET) {  
    struct sockaddr_in *dest4 = (struct sockaddr_in *) &sock->dest;
    inet_ntop(AF_INET, &dest4->sin_addr, res, INET_ADDRSTRLEN);
  }
  return res;
}

/* 
   send to the destination address
 */
ssize_t sock_sendto(ip_obj_t *sock, char *buf, size_t len) {
  char toaddr[INET6_ADDRSTRLEN];
  struct sockaddr *sa = (struct sockaddr *) &sock->dest;
  if (sa->sa_family == AF_INET6) {
    struct sockaddr_in6 *sa6 = (struct sockaddr_in6 *) &sock->dest;
    inet_ntop(AF_INET6, &sa6->sin6_addr, toaddr, INET6_ADDRSTRLEN);
    printf("to ipv6 address %s\n",toaddr);
    return sendto(sock->sockfd, buf, len, 0, 
		  (struct sockaddr *) &sock->dest, 
		  sizeof(struct sockaddr_in6));
  } else if (sa->sa_family == AF_INET) {
    struct sockaddr_in *sa4 = (struct sockaddr_in *) &sock->dest;
    inet_ntop(AF_INET, &sa4->sin_addr, toaddr, INET_ADDRSTRLEN);
    printf("to ipv4 address %s\n",toaddr);
    return sendto(sock->sockfd, buf, len, 0, 
		  (struct sockaddr *) &sock->dest, 
		  sizeof(struct sockaddr_in));
  }						
  return 0;
}


/* receive from an ip socket */
ssize_t sock_recvfrom(ip_obj_t *sock, char *buf, size_t len) {
  uint fromlen = sizeof(struct sockaddr_in6);
  ssize_t rcv = recvfrom(sock->sockfd, buf, len, 0, 
			 (struct sockaddr *) &sock->from, &fromlen);
  return rcv;
}

/* send back to whatever it came from */
ssize_t sock_sendbackto(ip_obj_t *sock, char *buf, size_t len) {
  struct sockaddr *sa = (struct sockaddr *) &sock->from;
  if (sa->sa_family == AF_INET6) {    
    return sendto(sock->sockfd, buf, len, 0,
		  (struct sockaddr *) &sock->from, 
		  sizeof(struct sockaddr_in6));
  } else if (sa->sa_family == AF_INET) {
    return sendto(sock->sockfd, buf, len, 0,
		  (struct sockaddr *) &sock->from, 
		  sizeof(struct sockaddr_in));
  }
  return -1;
}

