/*
 */

/**
 * @author David Culler
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "ip_socket.h"

#define MAXBUF  8192

void onintr() 
{
  exit(0);
}

void error(char *msg)
{
  perror(msg);
  exit(1);
}

int main(int argc, char *argv[])
{

  char *ns;
  char buf[MAXBUF];
  int port;
  int n;
  
  if (argc != 2) {
    printf("USAGE: %s port\n", argv[0]);
    exit(1);
  }
  port = atoi(argv[1]);
  printf("use cntl-c to exit\n");
  
  /* setup clean-up handler on interrupt */
  signal(SIGINT, onintr);

  ip_obj_t *sock = sock_udp_server(port);
  if (!sock) 
    error("ERROR creating socket");
  
  printf("created socket for %d\n", sock->sockfd);
  
  while (1)
    {
      /* read response from socket */
      memset(buf, 0, sizeof(buf));
      if ((n = sock_recvfrom(sock, buf, sizeof(buf)))  <= 0)
	error("ERROR reading from socket");
      
      printf("recv\n");
      /* create readable form of IPv addr */
      ns = sock_getaddr(sock);
      printf("%s: %s", ns, buf);
      free(ns);

      /* echo message back to client */
      if ((n = sock_sendbackto(sock, buf, sizeof(buf))) <= 0) 
	error("ERROR writing socket");
    }
  return 0;
}
